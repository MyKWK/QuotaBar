#!/usr/bin/env bash
# Rebuild QuotaBar, pack a local DMG, and replace /Applications/QuotaBar.app.
#
# This script may replace the app bundle only. It must never create, modify,
# or delete user-level data such as:
#   ~/Library/Application Support/QuotaBar/**
#   ~/Library/Preferences/com.local.quotabar.plist
#   ~/.quotabar.json
#   ~/.quotabar-credentials.json
#   macOS Keychain items
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$ROOT_DIR/.cursor/state"
DIRTY_FILE="$STATE_DIR/dmg-reinstall-needed"
APP_NAME="QuotaBar"
INSTALL_DIR="${QUOTABAR_INSTALL_DIR:-/Applications}"
DEST="$INSTALL_DIR/$APP_NAME.app"
ARCH="$(uname -m)"

case "$ARCH" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported arch: $ARCH" >&2
        exit 1
        ;;
esac

mkdir -p "$STATE_DIR"

if [ "${1:-}" = "--mark-dirty" ]; then
    date +%s > "$DIRTY_FILE"
    exit 0
fi

PROTECTED_FILES="
$HOME/Library/Application Support/QuotaBar/credentials.json
$HOME/Library/Application Support/QuotaBar/accounts.json
$HOME/Library/Application Support/QuotaBar/secrets.json
$HOME/Library/Preferences/com.local.quotabar.plist
$HOME/Library/Preferences/com.chiloh.QuotaBar.plist
$HOME/.quotabar.json
$HOME/.quotabar-credentials.json
"
PROTECTED_DIRS="
$HOME/Library/Application Support/QuotaBar
$HOME/Library/Application Support/QuotaBar/profiles
$HOME/Library/Application Support/QuotaBar/quota-cache
"

assert_not_protected() {
    local candidate="$1"
    local protected
    while IFS= read -r protected; do
        [ -n "$protected" ] || continue
        case "$candidate" in
            "$protected"|"$protected"/*)
                echo "Refusing to modify user data: $candidate" >&2
                exit 1
                ;;
        esac
    done <<EOF
$PROTECTED_FILES
$PROTECTED_DIRS
EOF
}

fingerprint_file() {
    local path="$1"
    if [ -f "$path" ]; then
        stat -f '%z' "$path"
    else
        echo "absent"
    fi
}

snapshot_protected() {
    local path
    echo "$PROTECTED_FILES" | while IFS= read -r path; do
        [ -n "$path" ] || continue
        printf 'file\t%s\t%s\n' "$path" "$(fingerprint_file "$path")"
    done
    echo "$PROTECTED_DIRS" | while IFS= read -r path; do
        [ -n "$path" ] || continue
        if [ -d "$path" ]; then
            printf 'dir\t%s\tpresent\n' "$path"
        else
            printf 'dir\t%s\tabsent\n' "$path"
        fi
    done
}

lookup_snapshot() {
    local snap_file="$1"
    local kind="$2"
    local path="$3"
    awk -F '\t' -v kind="$kind" -v path="$path" '$1 == kind && $2 == path { print $3; found=1; exit } END { if (!found) print "absent" }' "$snap_file"
}

quit_running_app() {
    if ! pgrep -xq "$APP_NAME"; then
        return 0
    fi
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    local i=0
    while [ "$i" -lt 40 ]; do
        pgrep -xq "$APP_NAME" || return 0
        sleep 0.25
        i=$((i + 1))
    done
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    sleep 0.5
}

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/quotabar-reinstall.XXXXXX")"
BEFORE_SNAP="$WORKDIR/before.snap"
AFTER_SNAP="$WORKDIR/after.snap"
MOUNT_DIR="$WORKDIR/dmg-mount"
TMP_DEST="$WORKDIR/$APP_NAME.app"
BACKUP_DEST="$DEST.previous"

cleanup() {
    if [ -n "${MOUNT_DIR:-}" ]; then
        hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
    fi
    rm -rf "$WORKDIR"
    rm -rf "$BACKUP_DEST"
}
trap cleanup EXIT

assert_not_protected "$WORKDIR"
assert_not_protected "$TMP_DEST"
assert_not_protected "$BACKUP_DEST"
assert_not_protected "$DEST"

snapshot_protected > "$BEFORE_SNAP"

echo "Building $APP_NAME $ARCH DMG from $ROOT_DIR"
quit_running_app

export QUOTABAR_SKIP_DMG_LAYOUT=true
"$ROOT_DIR/scripts/build_macos_app.sh" --arch "$ARCH"

VERSION="$("$ROOT_DIR/scripts/release_version.sh" current)"
DMG_PATH="$ROOT_DIR/dist/releases/$APP_NAME-$VERSION-$ARCH.dmg"
if [ ! -f "$DMG_PATH" ]; then
    echo "Built DMG missing: $DMG_PATH" >&2
    exit 1
fi

mkdir -p "$MOUNT_DIR"
if ! hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_DIR" >/dev/null; then
    echo "Unable to mount $DMG_PATH" >&2
    exit 1
fi

APP_SOURCE="$(find "$MOUNT_DIR" -maxdepth 3 -name "$APP_NAME.app" -type d -print -quit)"
if [ -z "$APP_SOURCE" ] || [ ! -d "$APP_SOURCE" ]; then
    echo "$APP_NAME.app not found in DMG" >&2
    exit 1
fi

ditto "$APP_SOURCE" "$TMP_DEST"
if [ ! -x "$TMP_DEST/Contents/MacOS/$APP_NAME" ]; then
    echo "Built app is missing its executable" >&2
    exit 1
fi

xattr -dr com.apple.quarantine "$TMP_DEST" >/dev/null 2>&1 || true
mkdir -p "$INSTALL_DIR"
if [ -e "$DEST" ]; then
    rm -rf "$BACKUP_DEST"
    mv "$DEST" "$BACKUP_DEST"
fi
if ! mv "$TMP_DEST" "$DEST"; then
    if [ -e "$BACKUP_DEST" ] && [ ! -e "$DEST" ]; then
        mv "$BACKUP_DEST" "$DEST"
    fi
    echo "Unable to install $DEST" >&2
    exit 1
fi
rm -rf "$BACKUP_DEST"

snapshot_protected > "$AFTER_SNAP"

changed=0
while IFS='	' read -r kind path before_value; do
    [ -n "${kind:-}" ] || continue
    after_value="$(lookup_snapshot "$AFTER_SNAP" "$kind" "$path")"
    case "$kind" in
        file)
            if [ "$before_value" != "absent" ] && [ "$after_value" = "absent" ]; then
                echo "User data disappeared during install: $path" >&2
                changed=1
            elif [ "$before_value" != "absent" ] && [ "$after_value" != "$before_value" ]; then
                echo "User data changed during install: $path" >&2
                changed=1
            fi
            ;;
        dir)
            if [ "$before_value" = "present" ] && [ "$after_value" != "present" ]; then
                echo "User data directory disappeared during install: $path" >&2
                changed=1
            fi
            ;;
    esac
done < "$BEFORE_SNAP"

if [ "$changed" -ne 0 ]; then
    exit 1
fi

rm -f "$DIRTY_FILE"
open "$DEST"
echo "Installed $DEST from $DMG_PATH"
echo "User credentials and Application Support data were left untouched."
