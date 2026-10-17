import Foundation

// MARK: - Menu bar capsule presentation
//
// Pure formatting for the status bar: one single-line capsule per enabled
// service (percent remaining, or a prepaid balance). No periodic window
// numbers, no multi-line text. Plugins with no live reading render their
// placeholder so nothing is fabricated.

struct StatusBarServiceInput {
    let service: ServiceKind
    let remainingPercent: Int?
    var headline: String? = nil
    var placeholderHeadline: String = "--%"
    var headlineKind: QuotaHeadlineKind = .remainingPercent
    var warningLevel: QuotaWarningLevel? = nil

    init(
        service: ServiceKind,
        remainingPercent: Int?,
        headline: String? = nil,
        placeholderHeadline: String = "--%",
        headlineKind: QuotaHeadlineKind = .remainingPercent,
        warningLevel: QuotaWarningLevel? = nil
    ) {
        self.service = service
        self.remainingPercent = remainingPercent
        self.headline = headline
        self.placeholderHeadline = placeholderHeadline
        self.headlineKind = headlineKind
        self.warningLevel = warningLevel
    }
}

enum StatusBarServiceWarningLevel: Equatable {
    case normal
    case low
    case exhausted
}

struct StatusBarServiceEntry: Equatable {
    let service: ServiceKind
    /// Single-line text drawn next to the logo, e.g. "100%", "¥110.00", or "--%".
    let text: String
    let hasData: Bool
    let level: StatusBarServiceWarningLevel
    var headlineKind: QuotaHeadlineKind = .remainingPercent
}

enum StatusBarServicesPresenter {
    // Same thresholds as the dashboard cards: <=20% is a warning, 0% is exhausted.
    static let lowRemainingThresholdPercent = 20

    static func entries(for inputs: [StatusBarServiceInput]) -> [StatusBarServiceEntry] {
        inputs.map { input in
            if let percent = input.remainingPercent {
                let clamped = min(max(percent, 0), 100)
                let level: StatusBarServiceWarningLevel
                if clamped <= 0 {
                    level = .exhausted
                } else if clamped <= lowRemainingThresholdPercent {
                    level = .low
                } else {
                    level = .normal
                }
                return StatusBarServiceEntry(
                    service: input.service,
                    text: "\(clamped)%",
                    hasData: true,
                    level: level,
                    headlineKind: .remainingPercent
                )
            }
            if let headline = input.headline, !headline.isEmpty {
                return StatusBarServiceEntry(
                    service: input.service,
                    text: headline,
                    hasData: true,
                    level: mapped(input.warningLevel),
                    headlineKind: input.headlineKind
                )
            }
            return StatusBarServiceEntry(
                service: input.service,
                text: input.placeholderHeadline,
                hasData: false,
                level: .normal,
                headlineKind: input.headlineKind
            )
        }
    }

    static func tooltip(for entries: [StatusBarServiceEntry]) -> String {
        guard !entries.isEmpty else {
            return "QuotaBar：在设置中开启要显示的服务"
        }
        return entries
            .map { entry in
                guard entry.hasData else {
                    return "\(entry.service.displayName) 暂无额度数据"
                }
                switch entry.headlineKind {
                case .balance:
                    return "\(entry.service.displayName) 余额 \(entry.text)"
                case .remainingPercent:
                    return "\(entry.service.displayName) 剩余 \(entry.text)"
                }
            }
            .joined(separator: "\n")
    }

    private static func mapped(_ level: QuotaWarningLevel?) -> StatusBarServiceWarningLevel {
        switch level {
        case .exhausted:
            return .exhausted
        case .low:
            return .low
        case .normal, nil:
            return .normal
        }
    }
}
