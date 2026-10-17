<div align="center">

# QuotaBar

### AI 额度，抬头就看见。

Codex / GPT · Kimi · Cursor · DeepSeek<br>
把分散在各个平台的额度和余额，放进 Mac 顶部菜单栏。

**简体中文** · [繁體中文](README.zh-TW.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português (Brasil)](README.pt-BR.md) · [快速开始](#快速开始) · [功能与接入状态](#功能与接入状态) · [反馈建议](https://github.com/MyKWK/QuotaBar/issues)

![macOS 27+](https://img.shields.io/badge/macOS-27%2B-black?logo=apple)
![Swift 6.4+](https://img.shields.io/badge/Swift-6.4%2B-F05138?logo=swift&logoColor=white)
![Local first](https://img.shields.io/badge/Local-first-6A8A78)

<img src="docs/images/quotabar-menubar.png" alt="QuotaBar 顶部栏实拍：Codex 21%、Kimi 90%、Cursor 92%，DeepSeek 尚无数据" width="530">

**少开几个用量页面，多留一点专注。**

</div>

写代码、切模型、跑任务时，你可能只想知道：还剩多少额度，现在该用哪个工具。

QuotaBar 常驻 macOS 菜单栏，用服务图标和简洁数字同时展示多个 AI 工具的余量。无需在网页、设置和终端之间来回寻找，抬头看一眼，就能继续手上的工作。

![QuotaBar 在真实桌面中的效果；顶部栏保留，屏幕正文已雾化去信息化](docs/images/quotabar-desktop-privacy.png)

<sub>真实使用截图。顶部栏来自原图；其余区域使用柔和雾化去除项目、代码和窗口信息，无马赛克。图中数值仅代表截图时刻，`--` 表示没有可用读数。</sub>

## 这个版本有什么不同

- **多服务同屏**：Codex / GPT、Kimi、Cursor 和 DeepSeek 可在同一条菜单栏中显示，也能按需隐藏。
- **每个数字都有含义**：Codex 展示可用额度窗口中的瓶颈余量；Cursor 可选 Cursor Models 或 Other Models 额度池；DeepSeek 展示实际余额，而非虚构的百分比。
- **原生玻璃界面**：基于 AppKit、SwiftUI 和 macOS 27 的玻璃材质；设置、服务详情与菜单栏保持统一视觉。
- **本地额度流水**：以 SQLite 记录小时采样，提供日、周、月、季、年的聚合视图、环图与热力图。
- **已有账号能力继续保留**：沿用原项目的 Codex、Cursor、Claude Code 多账号查看与切换能力。
- **轻量原生**：Swift Package Manager 构建，无第三方运行时依赖。

## 功能与接入状态

| 服务 | 当前能力 | 配置方式 |
| --- | --- | --- |
| Codex / GPT | 读取本机 Codex 登录账号的用量，展示可用窗口中的最低剩余比例 | 先在本机完成 Codex 登录；不是通用 ChatGPT 消息额度统计 |
| Kimi | 会员用量、剩余比例及刷新 | 在设置中保存自己的访问令牌 / 刷新令牌；会员接口未公开文档，可能随服务端变化 |
| Cursor | 查看当前账号额度，选择 Cursor Models / Other Models 额度池 | 使用本机 Cursor 登录状态 |
| DeepSeek | 官方 API 余额查询，显示赠金与充值合计可用余额 | 配置自己的 API Key，或提供环境变量名 |
| ZCode | 预留插件位置 | **尚未实现，不提供真实额度读数** |
| Claude Code | 保留原项目账号面板与 Provider | 当前不作为新增多服务菜单栏的独立项目 |

> 本地历史图表展示采样间的额度百分点变化，不等于 Token 数、账单金额或工作时长。DeepSeek 余额暂不计入聚合消耗图。采样缺失的时间不会补造记录。

## 快速开始

### 系统要求

- **macOS 27 或更高版本**。这个定制版使用 macOS 27 的原生界面 API，不能按原项目的 macOS 13 要求安装。
- Xcode 27.x / Swift 6.4 工具链。
- 当前仓库先提供源码；尚未发布本定制版的 GitHub 安装包。

### 从源码运行

```bash
git clone https://github.com/MyKWK/QuotaBar.git
cd QuotaBar
swift build
swift run QuotaBar
```

运行后在系统菜单栏找到 QuotaBar，打开面板和设置，选择要展示的服务并配置自己的账号。未配置的服务会显示未知状态，读数以各平台实际返回为准。

### 本地打包

```bash
QUOTABAR_SKIP_DMG_LAYOUT=true QUOTABAR_SKIP_VERSION_CHECK=true \
  scripts/build_macos_app.sh --arch arm64 --version 0.0.0-dev
```

打包文件位于 `dist/releases/`。Intel Mac 可选择 `--arch x86_64`，通用包可选择 `--arch universal`；本次源码发布在 Apple Silicon 上验证，其他架构尚未实机验收。

`scripts/reinstall_local_dmg.sh` 会替换并重启本机 `/Applications/QuotaBar.app`，仅在你确实需要安装时运行。仓库保留的 `.cursor/` 开发钩子也会在修改应用代码后提示重装；它们不属于运行应用的必要条件。

## 隐私与凭据

- 本仓库只包含代码、测试、资源和文档，**不附带任何可用账号、API Key 或登录令牌**。
- Kimi 令牌与选择直接保存的 DeepSeek Key 位于本机 `~/Library/Application Support/QuotaBar/credentials.json`，文件权限为 `0600`，目录权限为 `0700`。这是本地受权限保护的明文文件，并非全部加密保存在 Keychain。
- 原项目的多账号凭据使用 macOS Keychain；兼容代码也可能读取本机工具配置和旧凭据文件。
- 额度查询会携带所需凭据访问对应服务；应用不提供自有云端账号服务。更新检查只指向本仓库的 Releases，避免用原版覆盖定制版。
- 账号、缓存、历史 SQLite 数据库、日志、构建产物及原始桌面截图不纳入发布。

更多细节见 [安全说明](SECURITY.md)。分享问题时，请自行删除账号、令牌和日志中的个人信息。

## 开发与贡献

```bash
swift test
bash scripts/check_style.sh
bash scripts/check_no_signing_material.sh
python3 scripts/check_public_files.py
```

GitHub Actions 的 CI、打包与发布说明同步源码完整保存在 [`docs/workflow-templates/`](docs/workflow-templates/)。当前 GitHub 登录授权没有 `workflow` 权限，工作流暂未启用；获得相应授权并具备 macOS 27 / Xcode 27 runner 后可移至 `.github/workflows/`。

[九种语言宣传文案](docs/PROMOTION.md) 可用于项目分享；这些是介绍文档的语言，不代表应用界面已支持九种语言。

新服务通过 `QuotaServicePlugin` 接入，并在 `QuotaServiceRegistry` 注册。界面和历史记录消费统一读数，方便继续扩展。[贡献指南](CONTRIBUTING.md) · [架构说明](docs/architecture.md)

如果它让你少打开几个额度页面，欢迎给仓库一个 Star，也欢迎提交使用体验、问题和新的服务接入。

## 项目沿革、原创工作与致谢

QuotaBar 最早是我们自己开发的本机 Kimi 额度工具，2026 年 8 月 26 日已有运行与接口验证记录。顶部栏的多服务展示、类似系统设置的布局，以及后续扩展，按 MyKWK 的产品设计逐步实现。

2026 年 9 月 16 日，多服务开发引入了 [Chiloh / chilohwei 维护的另一个同名 QuotaBar 项目](https://github.com/chilohwei/QuotaBar) 作为集成基础，将我们已有的 Kimi 功能迁入，并继续扩展服务接入、设置与本机额度历史。当前版本由 **MyKWK** 维护，包含我们的原创工作与实际沿用的社区代码。

外部代码保留原作者版权、署名和完整 [QuotaBar Custom License](LICENSE)。详细过程见 [来源沿革](docs/ORIGINS.md)。感谢原作者提供的原生应用与账号管理代码。

本项目与所引用的社区项目及各 AI 服务商均无官方隶属或背书关系。原许可允许个人、教育、研究及其他非商业用途；商业用途需事先获得原作者书面授权。请阅读完整许可，不应将本仓库理解为 MIT / Apache 等宽松授权。

`docs/releases/` 中原有的版本说明记录上游历史，不代表本定制版已经发布对应安装包。各服务图标和商标归其权利人所有。
