import AppKit
import Charts
import SwiftUI

// MARK: - Aggregated quota history
//
// Hourly SQLite rows stay the source of truth. The ring and heatmap follow
// the selected lookback (day / week / month / quarter / year). Prepaid
// balance (DeepSeek) and Token totals are not in these charts yet.

struct QuotaHistorySettingsView: View {
    let store: QuotaHistoryStore
    @ObservedObject var recorder: QuotaHistoryRecorder
    @Environment(\.colorScheme) private var colorScheme
    @State private var period: QuotaHistoryPeriod = .day
    @State private var snapshot = QuotaHistorySnapshot(
        period: .day,
        periodStart: .now,
        slices: [],
        heat: .hours([])
    )
    @State private var loadError: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            GlassEffectContainer(spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("流水账")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Branding.inkStrong)
                        .glassLegibleInk()

                    Text("按小时记下各工具的额度消耗百分比，这里展示聚合结果。Token 计量尚未接入，DeepSeek 余额暂不计入。")
                        .font(.system(size: 11))
                        .foregroundStyle(Branding.inkMuted)
                        .glassLegibleInk()
                        .fixedSize(horizontal: false, vertical: true)

                    periodCard

                    if let loadError {
                        Label(loadError, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundStyle(Branding.warning)
                            .frostedGlassCard()
                    } else {
                        ringCard
                        heatmapCard
                    }

                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: recorder.revision) {
            reload()
        }
        .onChange(of: period) {
            reload()
        }
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("统计范围")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Branding.inkMuted)

            Slider(
                value: Binding(
                    get: { Double(period.rawValue) },
                    set: { period = QuotaHistoryPeriod(rawValue: Int($0.rounded())) ?? .day }
                ),
                in: 0...Double(QuotaHistoryPeriod.allCases.count - 1),
                step: 1
            )
            .tint(Branding.accentBlue)
            .accessibilityLabel("统计范围")
            .accessibilityValue(period.title)

            HStack(spacing: 0) {
                ForEach(QuotaHistoryPeriod.allCases) { item in
                    Button {
                        period = item
                    } label: {
                        Text(item.title)
                            .font(.system(size: 10, weight: item == period ? .semibold : .regular))
                            .foregroundStyle(item == period ? Branding.inkStrong : Branding.inkMuted)
                            .frame(maxWidth: .infinity, alignment: periodLabelAlignment(item))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(item == period ? [.isSelected] : [])
                }
            }
        }
        .frostedGlassCard()
    }

    private var ringCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(period.ringTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Branding.inkMuted)
                .glassLegibleInk()
            Text("各 AI 额度消耗占比")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Branding.inkStrong)
                .glassLegibleInk()

            HStack(alignment: .center, spacing: 20) {
                QuotaUsageRingChart(slices: snapshot.slices)
                    .frame(width: 168, height: 168)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(ringAccessibilityLabel)

                if snapshot.slices.isEmpty {
                    Text(period.emptyCopy)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Branding.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(snapshot.slices) { slice in
                            sliceLegendRow(slice)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frostedGlassCard()
    }

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heatmapTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Branding.inkMuted)
                .glassLegibleInk()
            Text("用过的 AI 越多、额度消耗占比越高，颜色越深")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Branding.inkStrong)
                .glassLegibleInk()

            QuotaUsageHeatmap(
                layout: snapshot.heat,
                weekdaySymbols: QuotaHistoryAggregation.weekdaySymbols(calendar: .current)
            )

            HStack(spacing: 6) {
                Text("少")
                    .font(.system(size: 10))
                    .foregroundStyle(Branding.inkMuted)
                ForEach(Array(heatLegendIntensities.enumerated()), id: \.offset) { _, intensity in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(QuotaUsageHeatPalette.color(intensity: intensity, colorScheme: colorScheme))
                        .frame(width: 11, height: 11)
                }
                Text("多")
                    .font(.system(size: 10))
                    .foregroundStyle(Branding.inkMuted)
            }
        }
        .frostedGlassCard()
    }

    private var heatmapTitle: String {
        switch period {
        case .day: return "每小时热力"
        case .week: return "每日热力"
        case .month, .quarter, .year: return "每日热力"
        }
    }

    private var heatLegendIntensities: [Double] {
        [0, 0.25, 0.5, 0.75, 1]
    }

    private func periodLabelAlignment(_ item: QuotaHistoryPeriod) -> Alignment {
        switch item {
        case .day: return .leading
        case .year: return .trailing
        default: return .center
        }
    }

    private func sliceLegendRow(_ slice: QuotaUsageSlice) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(QuotaUsageChartStyle.color(for: slice.service))
                .frame(width: 8, height: 8)
            Text(slice.service.displayName)
                .font(.system(size: 11.5))
                .foregroundStyle(Branding.ink)
            Spacer(minLength: 8)
            Text(QuotaHistoryLedger.formatAmount(slice.consumedPercent, unit: .percent, metricKey: "monthly"))
                .font(.system(size: 11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Branding.ink)
            Text(shareText(slice.share))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Branding.inkMuted)
                .frame(minWidth: 36, alignment: .trailing)
        }
    }

    private var ringAccessibilityLabel: String {
        if snapshot.slices.isEmpty {
            return period.emptyCopy
        }
        let parts = snapshot.slices.map { slice in
            "\(slice.service.displayName) \(shareText(slice.share))"
        }
        return "\(period.ringTitle)各 AI 额度消耗占比：" + parts.joined(separator: "，")
    }

    private func shareText(_ share: Double) -> String {
        "\(QuotaHistoryLedger.formatNumber(share * 100))%"
    }

    private func reload() {
        let calendar = Calendar.current
        let range = QuotaHistoryAggregation.queryRange(
            now: Date(),
            calendar: calendar,
            period: period
        )
        do {
            let records = try store.hourRecords(from: range.from, to: range.to)
            snapshot = QuotaHistoryAggregation.snapshot(
                records: records,
                now: Date(),
                calendar: calendar,
                period: period
            )
            loadError = nil
        } catch {
            snapshot = QuotaHistorySnapshot(
                period: period,
                periodStart: .now,
                slices: [],
                heat: .hours([])
            )
            loadError = "无法读取小时流水"
        }
    }
}

struct QuotaUsageRingChart: View {
    var slices: [QuotaUsageSlice]

    var body: some View {
        ZStack {
            if slices.isEmpty {
                Circle()
                    .stroke(Branding.controlStroke, lineWidth: 14)
                    .padding(18)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("占比", slice.share),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.6
                    )
                    .cornerRadius(3)
                    .foregroundStyle(QuotaUsageChartStyle.color(for: slice.service))
                }
                .chartLegend(.hidden)
            }

            VStack(spacing: 1) {
                if slices.isEmpty {
                    Text("—")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Branding.inkMuted)
                } else {
                    Text("\(slices.count)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Branding.inkStrong)
                    Text("个工具")
                        .font(.system(size: 10))
                        .foregroundStyle(Branding.inkMuted)
                }
            }
        }
    }
}

struct QuotaUsageHeatmap: View {
    var layout: QuotaHeatLayout
    var weekdaySymbols: [String]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch layout {
            case .hours(let cells):
                hourRow(cells)
            case .days(let cells):
                dayRow(cells)
            case .weeks(let weeks):
                weekGrid(weeks)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("用量热力图")
        .accessibilityValue(heatmapAccessibilityValue)
    }

    private var cellSize: CGFloat {
        switch layout {
        case .hours, .days:
            return 14
        case .weeks(let weeks):
            if weeks.count > 26 { return 8 }
            if weeks.count > 14 { return 10 }
            return 12
        }
    }

    private var gap: CGFloat { 3 }

    private func hourRow(_ cells: [QuotaHeatDay]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: gap) {
                ForEach(cells) { cell in
                    heatCell(cell)
                }
            }
            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text(String(format: "%02d", hour))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Branding.inkMuted)
                        .frame(maxWidth: .infinity, alignment: hour == 0 ? .leading : .center)
                }
            }
        }
    }

    private func dayRow(_ cells: [QuotaHeatDay]) -> some View {
        let calendar = Calendar.current
        return HStack(spacing: gap) {
            ForEach(cells) { cell in
                VStack(spacing: 4) {
                    heatCell(cell)
                    Text(shortDayLabel(cell.dayStart, calendar: calendar))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Branding.inkMuted)
                }
            }
        }
    }

    private func weekGrid(_ weeks: [[QuotaHeatDay]]) -> some View {
        ScrollView(.horizontal, showsIndicators: weeks.count > 16) {
            VStack(alignment: .leading, spacing: 6) {
                monthHeader(weeks)
                HStack(alignment: .top, spacing: gap) {
                    VStack(alignment: .trailing, spacing: gap) {
                        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Branding.inkMuted)
                                .frame(width: 12, height: cellSize, alignment: .center)
                        }
                    }
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: gap) {
                            ForEach(week) { day in
                                heatCell(day)
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthHeader(_ weeks: [[QuotaHeatDay]]) -> some View {
        HStack(alignment: .center, spacing: gap) {
            Color.clear.frame(width: 12, height: 11)
            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                Text(monthLabel(for: week, weekIndex: index, weeks: weeks))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Branding.inkMuted)
                    .frame(width: cellSize, alignment: .leading)
                    .lineLimit(1)
            }
        }
    }

    private func heatCell(_ day: QuotaHeatDay) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(cellColor(day))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .stroke(
                        Branding.controlStroke,
                        lineWidth: day.kind == .future || day.kind == .outside ? 0 : 0.5
                    )
            )
            .help(helpText(day))
    }

    private func monthLabel(for week: [QuotaHeatDay], weekIndex: Int, weeks: [[QuotaHeatDay]]) -> String {
        guard let first = week.first else { return "" }
        let calendar = Calendar.current
        let month = calendar.component(.month, from: first.dayStart)
        if weekIndex == 0 {
            return "\(month)月"
        }
        let previous = weeks[weekIndex - 1].first.map {
            calendar.component(.month, from: $0.dayStart)
        }
        return previous == month ? "" : "\(month)月"
    }

    private func shortDayLabel(_ date: Date, calendar: Calendar) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let ordered = ["日", "一", "二", "三", "四", "五", "六"]
        return ordered[(weekday - 1 + 7) % 7]
    }

    private func cellColor(_ day: QuotaHeatDay) -> Color {
        switch day.kind {
        case .future, .outside:
            return Color.clear
        case .idle, .todayIdle:
            return QuotaUsageHeatPalette.color(intensity: 0, colorScheme: colorScheme)
        case .active:
            return QuotaUsageHeatPalette.color(intensity: day.intensity, colorScheme: colorScheme)
        }
    }

    private func helpText(_ day: QuotaHeatDay) -> String {
        let calendar = Calendar.current
        let title: String
        switch layout {
        case .hours:
            title = QuotaHistoryLedger.hourTitle(day.dayStart, calendar: calendar)
        case .days, .weeks:
            title = QuotaHistoryLedger.dayTitle(day.dayStart, now: Date(), calendar: calendar)
        }
        switch day.kind {
        case .future, .outside:
            return title
        case .idle, .todayIdle:
            return "\(title)：没有额度消耗"
        case .active:
            let names = QuotaHistoryAggregation.percentServices.compactMap { service in
                day.usageByService[service].map { _ in service.displayName }
            }
            let consumed = QuotaHistoryLedger.formatAmount(
                day.consumedPercent,
                unit: .percent,
                metricKey: "monthly"
            )
            return "\(title)：\(names.joined(separator: "、")) · 额度消耗 \(consumed)"
        }
    }

    private var heatmapAccessibilityValue: String {
        let active = layout.cells.filter { $0.kind == .active }
        if active.isEmpty {
            return "还没有聚合的额度消耗"
        }
        return "有用量的格子 \(active.count) 个"
    }
}

enum QuotaUsageChartStyle {
    static func color(for service: ServiceKind) -> Color {
        switch service {
        case .gpt:
            return Branding.accentBlue
        case .kimi:
            return Color(nsColor: NSColor(name: nil) { appearance in
                let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return dark
                    ? NSColor(calibratedRed: 0.42, green: 0.72, blue: 0.94, alpha: 1)
                    : NSColor(calibratedRed: 0.22, green: 0.62, blue: 0.88, alpha: 1)
            })
        case .cursor:
            return Branding.accentBlueDark
        case .deepseek, .zcode:
            return Branding.inkMuted
        }
    }
}

enum QuotaUsageHeatPalette {
    static func color(intensity: Double, colorScheme: ColorScheme) -> Color {
        let t = min(max(intensity, 0), 1)
        let unused = colorScheme == .dark ? Branding.chipSurface : Color.white
        if t <= 0 {
            return unused
        }
        return unused.mix(with: Branding.accentBlue, by: t)
    }
}
