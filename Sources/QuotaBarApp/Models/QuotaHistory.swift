import Foundation

/// Remaining quota or prepaid balance at one successful collection.
/// Plugins publish these on `QuotaServiceReading`; the history recorder
/// never inspects Kimi / Codex / Cursor / DeepSeek payloads directly.
struct QuotaHistoryPoint: Equatable, Sendable {
    /// Stable id within a service, e.g. `monthly`, `weekly`, `cursorModels`, `CNY`.
    var metricKey: String
    /// Remaining percent (0...100) or remaining balance in `unit`.
    var remaining: Double
    var unit: QuotaHistoryUnit
    /// True when this series is the capsule's current headline metric.
    var isCanonical: Bool

    init(
        metricKey: String,
        remaining: Double,
        unit: QuotaHistoryUnit = .percent,
        isCanonical: Bool = true
    ) {
        self.metricKey = metricKey
        self.remaining = remaining
        self.unit = unit
        self.isCanonical = isCanonical
    }
}

enum QuotaHistoryUnit: String, Equatable, Sendable {
    case percent
    case currency
}

struct QuotaHistorySample: Equatable, Sendable {
    var service: ServiceKind
    var metricKey: String
    var remaining: Double
    var unit: QuotaHistoryUnit
    var isCanonical: Bool
    var capturedAt: Date
}

/// One local-hour bucket for one service metric.
/// `consumed` is the sum of observed remaining decreases in that hour;
/// `restored` is the sum of increases (window reset or top-up).
struct QuotaHourRecord: Equatable, Sendable {
    var service: ServiceKind
    var metricKey: String
    var hourStart: Date
    var unit: QuotaHistoryUnit
    var opening: Double
    var closing: Double
    var consumed: Double
    var restored: Double
    var sampleCount: Int
    var lastSampleAt: Date
    var isCanonical: Bool
}

enum QuotaHistoryBucket: Equatable, Sendable {
    case hour
    case day
    case week
    case month
}

struct QuotaHistoryAggregate: Equatable, Sendable {
    var periodStart: Date
    var opening: Double
    var closing: Double
    var consumed: Double
    var restored: Double
    var sampleCount: Int
}

enum QuotaHistoryClock {
    static func hourStart(of date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: date)) ?? date
    }

    static func bucketStart(_ bucket: QuotaHistoryBucket, of date: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component
        switch bucket {
        case .hour:
            return hourStart(of: date, calendar: calendar)
        case .day:
            component = .day
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        }
        return calendar.dateInterval(of: component, for: date)?.start ?? date
    }
}
