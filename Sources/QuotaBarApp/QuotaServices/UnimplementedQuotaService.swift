import Foundation

/// Stub collector for a `ServiceKind` that has a menu-bar slot but no live
/// source yet. The shell still renders logo + "--%"; this plugin never invents
/// a number.
@MainActor
final class UnimplementedQuotaService: ObservableObject, QuotaServicePlugin {
    let kind: ServiceKind
    let isImplemented = false
    let isRefreshing = false
    let reading: QuotaServiceReading

    init(kind: ServiceKind) {
        self.kind = kind
        self.reading = QuotaServiceReading(
            remainingPercent: nil,
            metricTitle: "额度接入规划中",
            setup: Self.setup(for: kind),
            origin: Self.origin(for: kind)
        )
    }

    func start() {}
    func stop() {}
    func refresh() {}

    static func setup(for kind: ServiceKind) -> QuotaSetupGuide {
        QuotaSetupGuide(
            paragraphs: [
                "\(kind.displayName) 尚未接入真实额度数据源，当前没有可配置的凭据或采集方式。"
            ]
        )
    }

    static func origin(for kind: ServiceKind) -> QuotaBalanceOrigin {
        let intro: String
        switch kind {
        case .zcode:
            intro = "ZCode 额度接入规划中，当前版本还没有真实数据源。"
        case .gpt, .kimi, .cursor, .deepseek:
            intro = "\(kind.displayName) 额度接入规划中，当前版本还没有真实数据源。"
        }
        return QuotaBalanceOrigin(
            paragraphs: [
                intro,
                "在「通用」页开启胶囊后，状态栏只会显示占位「--%」。接入真实数据源之前，不会编造任何百分比数字。"
            ]
        )
    }
}
