<div align="center">

# QuotaBar

### Your AI quota. One glance away.

Codex / GPT · Kimi · Cursor · DeepSeek<br>
Multiple AI services, right in your Mac menu bar.

[简体中文](README.md) · [繁體中文](README.zh-TW.md) · **English** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md) · [Get started](#get-started) · [Feedback](https://github.com/MyKWK/QuotaBar/issues)

<img src="docs/images/quotabar-menubar.png" alt="Real QuotaBar menu bar: Codex 21%, Kimi 90%, Cursor 92%, DeepSeek unavailable" width="530">

**Fewer usage tabs. More room to focus.**

</div>

Keep writing, building, and switching models without hunting through usage pages. QuotaBar brings compact service icons, remaining quotas, and account balances into the macOS menu bar.

![Real desktop screenshot with the original menu bar preserved and all desktop content anonymized using soft blur](docs/images/quotabar-desktop-privacy.png)

<sub>The menu bar is preserved from the real screenshot. Everything below it is anonymized with soft defocus, without pixelation. Values represent the moment of capture; `--` means no reading is available.</sub>

## What this edition adds

- **Multiple services at a glance:** show or hide Codex / GPT, Kimi, Cursor, and DeepSeek.
- **Meaningful numbers:** Codex uses the lowest remaining ratio among available windows; Cursor lets you choose its Cursor Models or Other Models pool; DeepSeek shows actual available balance.
- **Native glass surfaces:** AppKit, SwiftUI, and macOS 27 glass for the menu bar, details, and settings.
- **Local quota history:** hourly SQLite samples, with day/week/month/quarter/year summaries, ring charts, and heatmaps.
- **Existing account management:** retains the upstream Codex, Cursor, and Claude Code account panel and switching infrastructure.
- **Native Swift:** Swift Package Manager, with no third-party runtime dependencies.

## Service support

| Service | Implemented behavior | Setup |
| --- | --- | --- |
| Codex / GPT | Quota windows for your locally signed-in Codex account; lowest available remaining ratio | Sign in to Codex locally; this is not general ChatGPT message-quota tracking |
| Kimi | Membership usage and remaining percentage | Save your own access / refresh tokens in settings; the membership endpoint is undocumented and can change |
| Cursor | Current account quota; selectable Cursor Models / Other Models pool | Local Cursor sign-in |
| DeepSeek | Available API balance, including unexpired grants and top-ups | Your API key, or an environment-variable name |
| ZCode | Reserved plugin slot | **Not implemented; no live quota** |
| Claude Code | Upstream account panel and provider retained | Not a separate entry in the new multi-service menu bar |

History represents observed percentage-point changes between samples, not tokens, billing, or work hours. DeepSeek balances are currently excluded from aggregate consumption charts. Missing samples are not fabricated.

## Get started

Requires **macOS 27+ and Xcode 27.x / Swift 6.4**. This custom edition uses macOS 27 native APIs and does not share the upstream macOS 13 minimum. This repository currently distributes source; no custom-edition GitHub installer is published yet.

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

Find QuotaBar in the menu bar, open settings, choose services, and configure your own accounts. Unconfigured services show an unknown state.

### Build a local DMG

```bash
QUOTABAR_SKIP_DMG_LAYOUT=true QUOTABAR_SKIP_VERSION_CHECK=true \
  scripts/build_macos_app.sh --arch arm64 --version 0.0.0-dev
```

Outputs go to `dist/releases/`. The script also accepts `--arch x86_64` or `--arch universal`; this source publication is validated on Apple Silicon, not on physical Intel hardware.

`scripts/reinstall_local_dmg.sh` replaces and restarts `/Applications/QuotaBar.app`. Run it only when installation is intended. The included `.cursor/` development hooks can request reinstallation after app-source edits; they are not required to run the app.

## Privacy and credentials

- This repository contains code, tests, resources, and documentation, **without usable accounts, keys, or tokens**.
- Kimi tokens and directly saved DeepSeek keys live in `~/Library/Application Support/QuotaBar/credentials.json` with `0600` file and `0700` directory permissions. This is permission-protected plaintext, not encrypted Keychain storage.
- Upstream multi-account credentials use macOS Keychain. Compatibility paths may also read tool configuration and legacy credential files.
- Quota requests authenticate to each service. QuotaBar provides no cloud account backend. Update checks target this repository's Releases to avoid replacing this edition with upstream binaries.
- Accounts, caches, quota-history databases, logs, build products, and the original desktop screenshot are excluded from publication.

See [SECURITY.md](SECURITY.md). Remove personal details and credentials before sharing diagnostics.

## Development

```bash
swift test
bash scripts/check_style.sh
bash scripts/check_no_signing_material.sh
python3 scripts/check_public_files.py
```

All GitHub Actions CI, packaging, and release-note sync sources are retained in [`docs/workflow-templates/`](docs/workflow-templates/). They are currently inactive because the publishing OAuth authorization lacks `workflow` scope. With appropriate authorization and a macOS 27 / Xcode 27 runner, move them to `.github/workflows/` to enable automation.

[Promotional copy in nine languages](docs/PROMOTION.md) is available for sharing. These are documentation languages, not a claim that the app interface supports nine languages.

Add collectors through `QuotaServicePlugin` and register them in `QuotaServiceRegistry`. See [CONTRIBUTING.md](CONTRIBUTING.md) and [architecture](docs/architecture.md).

If QuotaBar saves you a few trips to usage pages, consider starring the repository or contributing feedback and new service integrations.

## Credits and license

QuotaBar began as our own local Kimi quota tool, with working app and API verification records dating to August 26, 2026. The multi-service menu bar, system-settings-style layout, and later extensions were developed around MyKWK’s product design.

On September 16, 2026, multi-service development integrated code from [a separate project also named QuotaBar, maintained by Chiloh / chilohwei](https://github.com/chilohwei/QuotaBar). Our existing Kimi functionality was migrated into that foundation, followed by additional service integrations, settings, and local quota history. This edition is maintained by **MyKWK** and combines our original work with retained community code.

The incorporated code retains the original copyright, attribution, and complete [QuotaBar Custom License](LICENSE). See [project origins](docs/ORIGINS.md) for the timeline. Thanks to the original author for the native application and account-management infrastructure.

This edition is not officially affiliated with or endorsed by the upstream project or any AI service. The original license permits personal, educational, research, and other non-commercial use; commercial use requires prior written authorization from the original author. This is not an MIT / Apache license.

Existing files under `docs/releases/` describe upstream history, not installer releases for this edition. Service icons and trademarks belong to their respective owners.
