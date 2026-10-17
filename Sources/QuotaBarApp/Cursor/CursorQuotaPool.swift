import Foundation

/// Which included-usage pool the Cursor menu-bar capsule displays.
///
/// Cursor Settings splits the cycle into two bars:
/// - Cursor Models (Grok / Composer) ← `autoPercentUsed`
/// - Other Models (third-party) ← `apiPercentUsed`
enum CursorQuotaPool: String, Codable, CaseIterable, Identifiable, Sendable {
    case cursorModels
    case otherModels

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursorModels:
            return "内部额度"
        case .otherModels:
            return "外部额度"
        }
    }

    var poolCaption: String {
        switch self {
        case .cursorModels:
            return "Cursor Models"
        case .otherModels:
            return "Other Models"
        }
    }

    var metricTitle: String {
        "\(displayName)剩余"
    }

    var windowLabel: String {
        switch self {
        case .cursorModels:
            return "Auto"
        case .otherModels:
            return "API"
        }
    }
}
