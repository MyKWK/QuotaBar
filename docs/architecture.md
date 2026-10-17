# 架构

QuotaBar 使用 Swift Package Manager，基于 AppKit、SwiftUI、Foundation 和 Security 构建。

## 模块职责

| 模块 | 职责 |
| --- | --- |
| `App` | 应用生命周期、状态栏、面板窗口、菜单和更新交互 |
| `Core` | 应用状态、账号操作、凭据协调、刷新策略、偏好与本地化 |
| `Models` | 账号、额度、消费、重置权益、服务身份（`ServiceKind`）及更新数据类型 |
| `QuotaServices` | 菜单栏额度采集插件：标准读数、注册表、未接入占位 |
| `Providers` | Codex / Cursor / Claude Code 的凭据解析、认证、接口请求与响应映射 |
| `Services` | HTTP、Keychain、文件访问、通知、进程管理和更新安装 |
| `Storage` | 账号元数据、快照缓存、小时额度流水（SQLite）和应用路径 |
| `UI` / `Settings` | 账号卡片、额度组件、以及按 `QuotaServiceReading` 渲染的设置页 |

## 状态与交互

`AppState` 是主线程上的应用状态入口。账号操作、界面交互、持久化、凭据协调、重启与刷新分别由对应扩展实现。视图通过 AppState 发起操作，Provider 返回数据模型；视图不直接读取 token 或调用网络接口。

`StatusBarController` 管理 AppKit 生命周期和状态栏展示。菜单栏胶囊只读 `QuotaServiceRegistry` 产出的标准读数（剩余百分比或预付余额）；左键与键盘导航通过 `NSStatusItem` 的 expanded interface 打开设置窗口。SwiftUI 负责内容排版，AppKit 负责窗口定位、事件和系统集成。设置窗口使用系统 `NSGlassEffectView.regular` 雾化玻璃并开启 `effectIsInteractive`，卡片使用 SwiftUI `glassEffect(.regular.interactive())`；强度固定、不可调节。正文使用不透明灰阶，并按窗口后方壁纸明暗切换浅色/深色方案，避免玻璃透出的桌面把字冲淡。系统开启「降低透明度」时回退为不透明背景并不再跟随壁纸。

## 菜单栏额度插件

状态栏与设置页是同一套壳：Logo、headline、说明文字只消费 `QuotaServiceReading`。采集实现 `QuotaServicePlugin`，由 `QuotaServiceRegistry` 按 `ServiceKind` 分发。会员类服务填 `remainingPercent`；预付余额类服务（DeepSeek）填货币 `headline`，不编造百分比。

当前插件：GPT（只读 Codex 本机会话）、Kimi（会员额度 + 凭据）、Cursor（只读 IDE 本周期用量）、DeepSeek（官方 `GET /user/balance` + API Key）、ZCode（`UnimplementedQuotaService` 占位）。新增工具：增加 `ServiceKind` 与 Logo，实现插件（或先挂占位），在注册表登记即可；壳层不必再写 `switch`。

## 额度与缓存

`QuotaSnapshot` 聚合账号额度及采集时间。窗口、点数、货币消费和重置权益使用独立类型，详见 [额度数据](provider-data.md)。账号级额度筛选由模型统一定义，卡片与菜单栏使用相同规则。

Provider 中传输与响应解析分离。HTTP 错误、认证失败和未知数据保留各自含义；缓存写入采用账号隔离与原子文件替换。主线程状态更新与凭据同步由 AppState 协调，账号切换使用对应服务的身份校验和写入规则。

## 小时额度流水

每次成功采集后，插件在 `QuotaServiceReading.historyPoints` 给出可记录的剩余额度或余额（Kimi 月度、GPT 的 5 小时/每周窗口、Cursor 内外两池、DeepSeek 各币种）。`QuotaHistoryRecorder` 按本地时区整点写入 `~/Library/Application Support/QuotaBar/quota-history.sqlite`。同一小时内多次采集会累计该小时的消耗（余额/剩余下降）和恢复（窗口重置或充值）。设置页「流水账」可滑动选择一天、一周、一个月、一个季度或一年：环形图是该范围内各工具额度消耗百分比的占比；热力图从白到蓝，用过的 AI 越多、消耗占比越高则越深。DeepSeek 余额与 Token 计量暂不计入图中。缺测的小时保持缺口、不做插值。

## 本地化

`AppLanguage`、`AppString` 和 `AppText` 提供简体中文、繁体中文、英文。本地化按界面、账号、错误、额度和字典组织，共享语言选择逻辑。日期、货币和倒计时根据各自数据含义格式化。

## 验证

`swift test` 覆盖接口映射、缓存兼容、账号身份与切换、令牌刷新、通知、更新来源和布局尺寸。发布流程运行测试并构建三种架构的 DMG；签名凭据存在时使用 Developer ID 和 Apple 公证。
