import Foundation

// MARK: - Standard plugin output
//
// Every quota collector maps its private payload into this shape. The status
// bar and settings shell never inspect Kimi membership stats, Codex snapshots,
// or Cursor windows directly.

struct QuotaServiceDetail: Equatable, Sendable {
    var label: String
    var value: String
}

/// How to obtain this tool's remaining-quota source. Rendered at the top of
/// the settings page so credential / login actions come before explanation.
struct QuotaSetupAction: Equatable, Sendable, Identifiable {
    var title: String
    var url: URL
    var systemImage: String

    var id: String { "\(title)|\(url.absoluteString)" }

    init(title: String, url: URL, systemImage: String = "safari") {
        self.title = title
        self.url = url
        self.systemImage = systemImage
    }
}

struct QuotaSetupGuide: Equatable, Sendable {
    var title: String
    var paragraphs: [String]
    var actions: [QuotaSetupAction]

    init(
        title: String = "获取方式",
        paragraphs: [String],
        actions: [QuotaSetupAction] = []
    ) {
        self.title = title
        self.paragraphs = paragraphs
        self.actions = actions
    }

    var hasContent: Bool {
        !paragraphs.isEmpty || !actions.isEmpty
    }
}

/// Per-tool explanation of how the capsule remaining percent is produced.
/// The settings shell renders this as a small card; plugins supply the copy.
struct QuotaBalanceOrigin: Equatable, Sendable {
    var title: String
    var paragraphs: [String]
    /// One line naming the window / field used for the live number, if any.
    var currentReading: String?

    init(
        title: String = "余额怎么来的",
        paragraphs: [String],
        currentReading: String? = nil
    ) {
        self.title = title
        self.paragraphs = paragraphs
        self.currentReading = currentReading
    }
}

/// How the capsule / settings headline should be read. Percent tools stay on
/// remaining-quota; prepaid APIs such as DeepSeek publish a currency balance.
enum QuotaHeadlineKind: Equatable, Sendable {
    case remainingPercent
    case balance
}

enum QuotaWarningLevel: Equatable, Sendable {
    case normal
    case low
    case exhausted
}

struct QuotaServiceReading: Equatable, Sendable {
    var remainingPercent: Int?
    /// Non-percent headline (e.g. "¥110.00"). Ignored when `remainingPercent` is set.
    var headline: String?
    /// Placeholder when there is no live number. Percent tools use "--%".
    var placeholderHeadline: String
    var headlineKind: QuotaHeadlineKind
    /// Optional capsule warning. Percent tools usually omit this and let the
    /// shell derive it from `remainingPercent`.
    var warningLevel: QuotaWarningLevel?
    /// Card heading above the big headline, e.g. "剩余额度" or "账户余额".
    var metricTitle: String
    /// Single line under the headline (plan name, or a status caption).
    var caption: String?
    var details: [QuotaServiceDetail]
    var lastUpdated: Date?
    var lastError: String?
    /// Extra explanation under the cards (read-only policy, unimplemented hint).
    var footnote: String?
    /// How to obtain credentials or otherwise start collecting this tool.
    var setup: QuotaSetupGuide?
    /// Dedicated “how this remaining percent is derived” card. Each plugin
    /// explains its own source and formula; the shell does not switch on kind.
    var origin: QuotaBalanceOrigin?
    var externalQuotaURL: URL?
    var externalQuotaURLTitle: String?
    /// Remaining values to persist as hourly history. Empty when this reading
    /// has nothing trustworthy to record (unimplemented, no live data).
    var historyPoints: [QuotaHistoryPoint]

    init(
        remainingPercent: Int? = nil,
        headline: String? = nil,
        placeholderHeadline: String = "--%",
        headlineKind: QuotaHeadlineKind = .remainingPercent,
        warningLevel: QuotaWarningLevel? = nil,
        metricTitle: String = "剩余额度",
        caption: String? = nil,
        details: [QuotaServiceDetail] = [],
        lastUpdated: Date? = nil,
        lastError: String? = nil,
        footnote: String? = nil,
        setup: QuotaSetupGuide? = nil,
        origin: QuotaBalanceOrigin? = nil,
        externalQuotaURL: URL? = nil,
        externalQuotaURLTitle: String? = nil,
        historyPoints: [QuotaHistoryPoint] = []
    ) {
        self.remainingPercent = remainingPercent
        self.headline = headline
        self.placeholderHeadline = placeholderHeadline
        self.headlineKind = headlineKind
        self.warningLevel = warningLevel
        self.metricTitle = metricTitle
        self.caption = caption
        self.details = details
        self.lastUpdated = lastUpdated
        self.lastError = lastError
        self.footnote = footnote
        self.setup = setup
        self.origin = origin
        self.externalQuotaURL = externalQuotaURL
        self.externalQuotaURLTitle = externalQuotaURLTitle
        self.historyPoints = historyPoints
    }

    /// Settings-page big number. Status-bar capsules clamp percent values separately.
    var displayedHeadline: String {
        if let remainingPercent {
            return "\(remainingPercent)%"
        }
        return headline ?? placeholderHeadline
    }

    var hasLiveHeadline: Bool {
        remainingPercent != nil || headline != nil
    }
}
