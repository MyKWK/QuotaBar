#!/usr/bin/env python3
"""Reject private runtime files and recognizable live-secret formats before publication.

This lightweight guard complements an external secret scanner; it is not a
guarantee that arbitrary personal data or unknown credential formats are absent.
It reports locations and rule names only, never the matched secret.
"""
from pathlib import Path
import re
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[1]
    raw = subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
        cwd=root,
    )
    names = sorted(set(item.decode() for item in raw.split(b'\0') if item))
    private_names = {
        'credentials.json', 'accounts.json', 'secrets.json', 'auth.json',
        '.quotabar.json', '.quotabar-credentials.json',
    }
    private_suffixes = {
        '.sqlite', '.sqlite3', '.db', '.log', '.pem', '.key', '.p12', '.pfx',
        '.p8', '.cer', '.der', '.mobileprovision', '.provisionprofile',
        '.keychain', '.keychain-db', '.dmg', '.app', '.zip',
    }
    # Concatenation keeps the guard's own literals from resembling credentials.
    patterns = {
        'private-key': re.compile('-' * 5 + r'BEGIN (?:[A-Z0-9 ]*)PRIVATE KEY' + '-' * 5),
        'github-token': re.compile(r'\bgh' + r'[pousr]_[A-Za-z0-9]{30,}\b'),
        'github-fine-grained-token': re.compile(r'github_' + r'pat_[A-Za-z0-9_]{30,}'),
        'api-key': re.compile(r'\bsk' + r'-[A-Za-z0-9_-]{28,}\b'),
        'jwt-literal': re.compile(r'\bey' + r'J[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'),
    }
    failures = []
    for name in names:
        path = Path(name)
        lowered = [part.lower() for part in path.parts]
        if (
            path.name.lower() in private_names
            or path.suffix.lower() in private_suffixes
            or path.name.startswith('.env')
            or path.name.startswith('codex-clipboard-')
            or any(part in {'.build', 'dist', 'node_modules', 'sessions'} for part in lowered)
            or lowered[:2] == ['.cursor', 'state']
            or '.sqlite-' in path.name.lower()
        ):
            failures.append((name, 'private/runtime file'))
        full_path = root / name
        if full_path.is_symlink():
            failures.append((name, 'symlink requires manual review'))
            continue
        if not full_path.is_file():
            continue
        try:
            content = full_path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            continue
        for rule, pattern in patterns.items():
            for match in pattern.finditer(content):
                line = content.count('\n', 0, match.start()) + 1
                failures.append((f'{name}:{line}', rule))
    if failures:
        for location, rule in failures:
            print(f'BLOCKED: {location}: {rule}', file=sys.stderr)
        return 1
    print(f'Public file guard passed: {len(names)} files; run an external secret scanner as well.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
