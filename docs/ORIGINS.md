# QuotaBar：项目沿革与代码来源

这个版本包含我们自己的产品与功能开发，也包含后来引入的社区代码。两个开发来源都应明确署名。

## 2026 年 8 月：我们的本机 Kimi 工具

2026 年 8 月 26 日「实现 Kimi 会员额度接口查询」的开发记录，已包含 Kimi 会员额度接口直连、登录续期、菜单栏显示及本机应用构建。旧版本使用单文件 `Sources/main.swift`，随后迁入用户自己的 iCloud 项目目录。

用户在该次开发中确认已实际看到 Kimi 剩余额度。保留的旧源码与 README 也记录了这条本机 Kimi 路线。因此，项目并不是从 9 月的社区代码开始。

## 2026 年 9 月：同名社区代码的引入与整合

9 月 16 日「查找Mac顶部栏余额显示工具」的开发中，需求扩展到多个服务，用户明确提出类似 macOS 系统设置的导航、逐服务显示开关与“Logo + 百分比”的顶部栏。

该次代理开发克隆了 [chilohwei/QuotaBar](https://github.com/chilohwei/QuotaBar)，基线提交是 [`5d7adbb205eaa09bed6cdc281ff106845a5fc688`](https://github.com/chilohwei/QuotaBar/commit/5d7adbb205eaa09bed6cdc281ff106845a5fc688)。随后将已有 Kimi 功能迁入，并加入我们设计的多服务界面。

本机 Git reflog 记录的克隆时间为 2026 年 9 月 16 日 15:27（Asia/Shanghai）。核对公开发布前的工作目录，原基线有 114 个源码文件保持逐字节相同，另有 13 个原有源码文件被修改，并增加了新的服务、设置及历史等模块。这些数字说明当前代码实际保留了外部实现；它们不是功能价值或贡献比例的估算。

## 2026 年 10 月：独立仓库发布

10 月 17 日，MyKWK 将当前整合版本发布到 [MyKWK/QuotaBar](https://github.com/MyKWK/QuotaBar)，剔除本机凭据、运行数据与原始桌面截图，并加入去信息化的展示图片。

GitHub 上这个独立仓库的 Star、Watch、Fork 与流量应单独统计，不能把社区项目的数据归入本仓库。

## 宣传与许可约定

- 项目由 MyKWK 发起产品设计并维护，最初的本机 Kimi 工具属于我们自己的开发路线。
- 当前整合版实际沿用了 Chiloh / chilohwei 的社区代码，相关代码的原始署名和完整 [许可](../LICENSE) 必须保留。
- 本文记录开发来源，不重新授予或变更任何代码的许可。
- 多语言 README 描述相同功能边界，不表示应用界面已经支持相同数量的语言。

## English summary

QuotaBar began as MyKWK’s own local Kimi quota tool, already working in August 2026. On September 16, development integrated code from a separate project with the same name, maintained by Chiloh / chilohwei. The current edition combines our original Kimi work, product design, and later extensions with retained community application and account-management code. Both origins deserve explicit attribution. The original license for incorporated code remains intact; this document does not change licensing.
