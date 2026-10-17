import Foundation

enum QuotaHistoryPeriod: Int, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case quarter
    case year

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .day: return "一天"
        case .week: return "一周"
        case .month: return "一个月"
        case .quarter: return "一个季度"
        case .year: return "一年"
        }
    }

    var ringTitle: String {
        switch self {
        case .day: return "这一天"
        case .week: return "这一周"
        case .month: return "这一个月"
        case .quarter: return "这一季度"
        case .year: return "这一年"
        }
    }

    var emptyCopy: String {
        "\(ringTitle)还没有额度消耗。有采集但剩余没下降时，这里会保持空。"
    }
}

/// Daily percent-quota usage derived from hourly SQLite rows.
/// Currency series (DeepSeek) and Token totals are out of scope.
enum QuotaHistoryAggregation {
    static let minimumConsumedPercent = 0.05
    /// Tools whose history is remaining-percent, not prepaid balance.
    static let percentServices: [ServiceKind] = [.gpt, .kimi, .cursor]

    static func queryRange(
        now: Date,
        calendar: Calendar,
        period: QuotaHistoryPeriod
    ) -> (from: Date, to: Date) {
        let today = calendar.startOfDay(for: now)
        let from: Date
        switch period {
        case .day:
            from = today
        case .week:
            from = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .month:
            from = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        case .quarter:
            from = calendar.date(byAdding: .month, value: -3, to: today) ?? today
        case .year:
            from = calendar.date(byAdding: .year, value: -1, to: today) ?? today
        }
        return (from, now.addingTimeInterval(3600))
    }

    static func snapshot(
        records: [QuotaHourRecord],
        now: Date,
        calendar: Calendar,
        period: QuotaHistoryPeriod
    ) -> QuotaHistorySnapshot {
        let range = queryRange(now: now, calendar: calendar, period: period)
        let today = calendar.startOfDay(for: now)
        let from = calendar.startOfDay(for: range.from)
        let usageByDay = percentUsage(from: records, calendar: calendar) { date, calendar in
            calendar.startOfDay(for: date)
        }
        let inRange = usageByDay.filter { $0.key >= from && $0.key <= today }
        let slices = Self.slices(from: combinedUsage(inRange))
        let maxConsumed = inRange.values.map { $0.values.reduce(0, +) }.max() ?? 0
        let heat: QuotaHeatLayout
        switch period {
        case .day:
            heat = .hours(
                hourCells(
                    records: records,
                    today: today,
                    now: now,
                    calendar: calendar
                )
            )
        case .week:
            heat = .days(
                dayRow(
                    usageByDay: inRange,
                    from: from,
                    today: today,
                    now: now,
                    calendar: calendar,
                    maxConsumed: maxConsumed
                )
            )
        case .month, .quarter, .year:
            heat = .weeks(
                heatWeeks(
                    usageByDay: inRange,
                    from: from,
                    today: today,
                    now: now,
                    calendar: calendar,
                    maxConsumed: maxConsumed
                )
            )
        }
        return QuotaHistorySnapshot(
            period: period,
            periodStart: from,
            slices: slices,
            heat: heat
        )
    }

    static func dailyPercentUsage(
        from records: [QuotaHourRecord],
        calendar: Calendar
    ) -> [Date: [ServiceKind: Double]] {
        percentUsage(from: records, calendar: calendar) { date, calendar in
            calendar.startOfDay(for: date)
        }
    }

    static func percentUsage(
        from records: [QuotaHourRecord],
        calendar: Calendar,
        bucket: (Date, Calendar) -> Date
    ) -> [Date: [ServiceKind: Double]] {
        var nested: [Date: [ServiceKind: [String: Double]]] = [:]
        for record in records {
            guard record.unit == .percent, record.consumed >= minimumConsumedPercent else {
                continue
            }
            let start = bucket(record.hourStart, calendar)
            nested[start, default: [:]][record.service, default: [:]][record.metricKey, default: 0]
                += record.consumed
        }
        var usage: [Date: [ServiceKind: Double]] = [:]
        for (start, services) in nested {
            var perService: [ServiceKind: Double] = [:]
            for (service, metrics) in services {
                let consumed = metrics.values.max() ?? 0
                if consumed >= minimumConsumedPercent {
                    perService[service] = consumed
                }
            }
            if !perService.isEmpty {
                usage[start] = perService
            }
        }
        return usage
    }

    static func combinedUsage(_ usage: [Date: [ServiceKind: Double]]) -> [ServiceKind: Double] {
        var combined: [ServiceKind: Double] = [:]
        for perService in usage.values {
            for (service, value) in perService {
                combined[service, default: 0] += value
            }
        }
        return combined
    }

    static func slices(from usage: [ServiceKind: Double]) -> [QuotaUsageSlice] {
        let ordered = percentServices.compactMap { service -> (ServiceKind, Double)? in
            guard let consumed = usage[service], consumed >= minimumConsumedPercent else {
                return nil
            }
            return (service, consumed)
        }
        let total = ordered.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }
        return ordered.map { service, consumed in
            QuotaUsageSlice(
                service: service,
                consumedPercent: consumed,
                share: consumed / total
            )
        }
    }

    static func intensity(
        toolsUsed: Int,
        consumedPercent: Double,
        maxConsumed: Double
    ) -> Double {
        guard toolsUsed > 0 else { return 0 }
        let capacity = Double(percentServices.count)
        let usagePart = maxConsumed > 0 ? min(1, consumedPercent / maxConsumed) : 0
        return (Double(toolsUsed) + usagePart * 0.99) / (capacity + 1)
    }

    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let ordered = ["日", "一", "二", "三", "四", "五", "六"]
        let start = max(0, min(6, calendar.firstWeekday - 1))
        return Array(ordered[start...] + ordered[..<start])
    }

    private static func hourCells(
        records: [QuotaHourRecord],
        today: Date,
        now: Date,
        calendar: Calendar
    ) -> [QuotaHeatDay] {
        let usage = percentUsage(from: records, calendar: calendar) { date, calendar in
            QuotaHistoryClock.hourStart(of: date, calendar: calendar)
        }
        let maxConsumed = usage.values.map { $0.values.reduce(0, +) }.max() ?? 0
        return (0..<24).map { hour in
            let start = calendar.date(byAdding: .hour, value: hour, to: today)
                ?? today.addingTimeInterval(TimeInterval(hour * 3600))
            return heatDay(
                dayStart: start,
                usage: usageMatching(start, in: usage, calendar: calendar),
                today: today,
                now: now,
                calendar: calendar,
                maxConsumed: maxConsumed,
                futureIfAfterNow: true
            )
        }
    }

    private static func usageMatching(
        _ start: Date,
        in usage: [Date: [ServiceKind: Double]],
        calendar: Calendar
    ) -> [ServiceKind: Double] {
        if let exact = usage[start] {
            return exact
        }
        let day = calendar.startOfDay(for: start)
        let hour = calendar.component(.hour, from: start)
        for (key, value) in usage {
            if calendar.startOfDay(for: key) == day,
               calendar.component(.hour, from: key) == hour {
                return value
            }
        }
        return [:]
    }

    private static func dayRow(
        usageByDay: [Date: [ServiceKind: Double]],
        from: Date,
        today: Date,
        now: Date,
        calendar: Calendar,
        maxConsumed: Double
    ) -> [QuotaHeatDay] {
        var days: [QuotaHeatDay] = []
        var cursor = from
        while cursor <= today {
            days.append(
                heatDay(
                    dayStart: cursor,
                    usage: usageByDay[cursor] ?? [:],
                    today: today,
                    now: now,
                    calendar: calendar,
                    maxConsumed: maxConsumed,
                    futureIfAfterNow: false
                )
            )
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? today.addingTimeInterval(86400)
            if days.count > 31 { break }
        }
        return days
    }

    private static func heatWeeks(
        usageByDay: [Date: [ServiceKind: Double]],
        from: Date,
        today: Date,
        now: Date,
        calendar: Calendar,
        maxConsumed: Double
    ) -> [[QuotaHeatDay]] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: from)?.start ?? from
        let lastWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        var weeks: [[QuotaHeatDay]] = []
        var cursor = weekStart
        while cursor <= lastWeekStart {
            var days: [QuotaHeatDay] = []
            for offset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: offset, to: cursor) ?? cursor
                let dayStart = calendar.startOfDay(for: day)
                if dayStart < from || dayStart > today {
                    days.append(
                        QuotaHeatDay(
                            dayStart: dayStart,
                            kind: dayStart > today ? .future : .outside,
                            usageByService: [:],
                            intensity: 0
                        )
                    )
                } else {
                    days.append(
                        heatDay(
                            dayStart: dayStart,
                            usage: usageByDay[dayStart] ?? [:],
                            today: today,
                            now: now,
                            calendar: calendar,
                            maxConsumed: maxConsumed,
                            futureIfAfterNow: false
                        )
                    )
                }
            }
            weeks.append(days)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor),
                  next > cursor else { break }
            cursor = next
            if weeks.count > 54 { break }
        }
        return weeks
    }

    private static func heatDay(
        dayStart: Date,
        usage: [ServiceKind: Double],
        today: Date,
        now: Date,
        calendar: Calendar,
        maxConsumed: Double,
        futureIfAfterNow: Bool
    ) -> QuotaHeatDay {
        let isFuture = futureIfAfterNow
            ? dayStart > now
            : dayStart > today
        if isFuture {
            return QuotaHeatDay(
                dayStart: dayStart,
                kind: .future,
                usageByService: [:],
                intensity: 0
            )
        }
        let consumed = usage.values.reduce(0, +)
        let toolsUsed = usage.count
        if toolsUsed == 0 {
            let isToday = calendar.isDate(dayStart, inSameDayAs: now)
            return QuotaHeatDay(
                dayStart: dayStart,
                kind: isToday ? .todayIdle : .idle,
                usageByService: [:],
                intensity: 0
            )
        }
        return QuotaHeatDay(
            dayStart: dayStart,
            kind: .active,
            usageByService: usage,
            intensity: intensity(
                toolsUsed: toolsUsed,
                consumedPercent: consumed,
                maxConsumed: maxConsumed
            )
        )
    }
}

struct QuotaUsageSlice: Equatable, Identifiable {
    var service: ServiceKind
    var consumedPercent: Double
    var share: Double
    var id: ServiceKind { service }
}

struct QuotaHeatDay: Equatable, Identifiable {
    enum Kind: Equatable {
        case future
        case outside
        case idle
        case todayIdle
        case active
    }

    var dayStart: Date
    var kind: Kind
    var usageByService: [ServiceKind: Double]
    var intensity: Double
    var id: Date { dayStart }

    var toolsUsed: Int { usageByService.count }
    var consumedPercent: Double { usageByService.values.reduce(0, +) }
}

enum QuotaHeatLayout: Equatable {
    case hours([QuotaHeatDay])
    case days([QuotaHeatDay])
    case weeks([[QuotaHeatDay]])

    var cells: [QuotaHeatDay] {
        switch self {
        case .hours(let cells), .days(let cells):
            return cells
        case .weeks(let weeks):
            return weeks.flatMap { $0 }
        }
    }
}

struct QuotaHistorySnapshot: Equatable {
    var period: QuotaHistoryPeriod
    var periodStart: Date
    var slices: [QuotaUsageSlice]
    var heat: QuotaHeatLayout

    var hasAnyUsage: Bool {
        heat.cells.contains { $0.kind == .active }
    }
}

extension QuotaHistoryLedger {
    static func queryRange(
        now: Date,
        calendar: Calendar,
        period: QuotaHistoryPeriod = .year
    ) -> (from: Date, to: Date) {
        QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: period)
    }
}
