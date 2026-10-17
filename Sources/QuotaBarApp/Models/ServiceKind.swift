import Foundation

/// Identity of a menu-bar / settings quota service. Display metadata (name,
/// logo, sidebar icon, capsule order) lives here; live numbers come from the
/// matching `QuotaServicePlugin` in `QuotaServiceRegistry`.
/// Separate from `ToolKind` (Codex / Cursor / Claude Code account switching).
enum ServiceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case kimi
    case gpt
    case cursor
    case deepseek
    case zcode

    var id: String { rawValue }

    /// Status-bar reading order follows the user's visual convention: GPT is
    /// the leftmost primary item, then Kimi, Cursor, DeepSeek, and ZCode.
    static let menuBarOrder: [ServiceKind] = [.gpt, .kimi, .cursor, .deepseek, .zcode]

    var displayName: String {
        switch self {
        case .kimi:
            return "Kimi"
        case .gpt:
            return "GPT"
        case .cursor:
            return "Cursor"
        case .deepseek:
            return "DeepSeek"
        case .zcode:
            return "ZCode"
        }
    }

    var logoResourceName: String {
        switch self {
        case .kimi:
            return "kimi"
        case .gpt:
            return "codex"
        case .cursor:
            return "cursor"
        case .deepseek:
            return "deepseek"
        case .zcode:
            return "zcode"
        }
    }
}
