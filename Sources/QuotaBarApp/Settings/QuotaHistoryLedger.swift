import Foundation

/// Groups hourly SQLite rows into the settings ledger.
/// Newest hour first; missing hours stay missing.
enum QuotaHistoryLedger {
    static func grouped(
        records: [QuotaHourRecord],
        calendar: Calendar
    ) -> [QuotaHistoryDayGroup] {
        let hours = Dictionary(grouping: records, by: \.hourStart)
            .map { hourStart, entries in
                QuotaHistoryHourGroup(
                    hourStart: hourStart,
                    entries: entries.sorted(by: entrySort)
                )
            }
            .sorted { $0.hourStart > $1.hourStart }

        var days: [QuotaHistoryDayGroup] = []
        var index: [Date: Int] = [:]
        for hour in hours {
            let dayStart = calendar.startOfDay(for: hour.hourStart)
            if let existing = index[dayStart] {
                days[existing].hours.append(hour)
            } else {
                index[dayStart] = days.count
                days.append(QuotaHistoryDayGroup(dayStart: dayStart, hours: [hour]))
            }
        }
        return days
    }

    static func dayTitle(_ dayStart: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(dayStart, inSameDayAs: now) {
            return "今天"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(dayStart, inSameDayAs: yesterday) {
            return "昨天"
        }
        return "\(calendar.component(.month, from: dayStart))月\(calendar.component(.day, from: dayStart))日"
    }

    static func hourTitle(_ hourStart: Date, calendar: Calendar) -> String {
        String(format: "%02d:00", calendar.component(.hour, from: hourStart))
    }

    static func entryTitle(_ record: QuotaHourRecord) -> String {
        "\(record.service.displayName) · \(metricTitle(service: record.service, metricKey: record.metricKey))"
    }

    static func metricTitle(service: ServiceKind, metricKey: String) -> String {
        switch service {
        case .kimi:
            return metricKey == "monthly" ? "月度" : metricKey
        case .gpt:
            switch metricKey.lowercased() {
            case "5h":
                return "5 小时"
            case "weekly", "7d", "7 days", "week":
                return "每周"
            default:
                return metricKey
            }
        case .cursor:
            return CursorQuotaPool(rawValue: metricKey)?.displayName ?? metricKey
        case .deepseek:
            return DeepSeekPayloadParser.currencyLabel(metricKey)
        case .zcode:
            return metricKey
        }
    }

    static func formatDelta(_ record: QuotaHourRecord) -> String {
        if record.consumed <= 0, record.restored <= 0 {
            return formatAmount(0, unit: record.unit, metricKey: record.metricKey)
        }
        var parts: [String] = []
        if record.consumed > 0 {
            parts.append("−" + formatAmount(record.consumed, unit: record.unit, metricKey: record.metricKey))
        }
        if record.restored > 0 {
            parts.append("+" + formatAmount(record.restored, unit: record.unit, metricKey: record.metricKey))
        }
        return parts.joined(separator: "  ")
    }

    static func formatRemaining(_ record: QuotaHourRecord) -> String {
        "余 " + formatAmount(record.closing, unit: record.unit, metricKey: record.metricKey)
    }

    static func formatAmount(_ value: Double, unit: QuotaHistoryUnit, metricKey: String) -> String {
        switch unit {
        case .percent:
            return "\(formatNumber(value))%"
        case .currency:
            return DeepSeekPayloadParser.currencySymbol(metricKey) + formatNumber(value, keepCurrencyCents: true)
        }
    }

    static func formatNumber(_ value: Double, keepCurrencyCents: Bool = false) -> String {
        let rounded = (value * 100).rounded() / 100
        if keepCurrencyCents {
            return String(format: "%.2f", rounded)
        }
        if abs(rounded - rounded.rounded()) < 0.0001 {
            return String(Int(rounded.rounded()))
        }
        let tenths = (rounded * 10).rounded() / 10
        if abs(rounded - tenths) < 0.0001 {
            return String(format: "%.1f", tenths)
        }
        return String(format: "%.2f", rounded)
    }

    private static func entrySort(_ left: QuotaHourRecord, _ right: QuotaHourRecord) -> Bool {
        let order = ServiceKind.menuBarOrder
        let leftIndex = order.firstIndex(of: left.service) ?? order.count
        let rightIndex = order.firstIndex(of: right.service) ?? order.count
        if leftIndex != rightIndex {
            return leftIndex < rightIndex
        }
        return left.metricKey < right.metricKey
    }
}

struct QuotaHistoryDayGroup: Equatable, Identifiable {
    var dayStart: Date
    var hours: [QuotaHistoryHourGroup]
    var id: Date { dayStart }
}

struct QuotaHistoryHourGroup: Equatable, Identifiable {
    var hourStart: Date
    var entries: [QuotaHourRecord]
    var id: Date { hourStart }
}
