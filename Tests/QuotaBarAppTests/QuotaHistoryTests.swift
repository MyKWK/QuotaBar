import AppKit
import Combine
import Foundation
import Testing
@testable import QuotaBarApp

@Suite("Quota history")
struct QuotaHistoryTests {
    @Test("hour clock floors to the local hour")
    func hourClockFloorsToLocalHour() {
        let calendar = Self.calendar
        let captured = Self.date(2026, 9, 17, 18, 33, calendar: calendar)
        let start = QuotaHistoryClock.hourStart(of: captured, calendar: calendar)
        #expect(start == Self.date(2026, 9, 17, 18, 0, calendar: calendar))
        #expect(
            QuotaHistoryClock.bucketStart(.day, of: captured, calendar: calendar)
                == Self.date(2026, 9, 17, 0, 0, calendar: calendar)
        )
        #expect(
            QuotaHistoryClock.bucketStart(.month, of: captured, calendar: calendar)
                == Self.date(2026, 9, 1, 0, 0, calendar: calendar)
        )
    }

    @Test("dark backdrops prefer light ink")
    func darkBackdropsPreferLightInk() {
        #expect(GlassBackdropLuminance.luminance(red: 1, green: 1, blue: 1) > 0.9)
        #expect(GlassBackdropLuminance.luminance(red: 0, green: 0, blue: 0) < 0.1)
        #expect(GlassBackdropLuminance.prefersDarkInterface(luminance: 0.2))
        #expect(!GlassBackdropLuminance.prefersDarkInterface(luminance: 0.7))
        let sampled = GlassBackdropLuminance.wallpaperRect(
            windowFrame: NSRect(x: 100, y: 50, width: 200, height: 100),
            screenFrame: NSRect(x: 0, y: 0, width: 1000, height: 500),
            imageSize: NSSize(width: 4000, height: 2000)
        )
        #expect(abs(sampled.minX - 400) < 0.001)
        #expect(abs(sampled.minY - 200) < 0.001)
        #expect(abs(sampled.width - 800) < 0.001)
        #expect(abs(sampled.height - 400) < 0.001)
    }

    @Test("first sample in an hour records remaining with zero consumption")
    func firstSampleHasZeroConsumption() throws {
        try withStore { store, calendar in
            let captured = Self.date(2026, 9, 17, 18, 10, calendar: calendar)
            try store.record(Self.sample(remaining: 80, at: captured))
            let records = try store.hourRecords(
                service: .kimi,
                metricKey: "monthly",
                from: Self.date(2026, 9, 17, 0, 0, calendar: calendar),
                to: Self.date(2026, 9, 18, 0, 0, calendar: calendar)
            )
            #expect(records.count == 1)
            #expect(records[0].hourStart == Self.date(2026, 9, 17, 18, 0, calendar: calendar))
            #expect(records[0].opening == 80)
            #expect(records[0].closing == 80)
            #expect(records[0].consumed == 0)
            #expect(records[0].restored == 0)
            #expect(records[0].sampleCount == 1)
            #expect(records[0].isCanonical)
        }
    }

    @Test("remaining decreases in the same hour accumulate as consumed")
    func decreasesAccumulateConsumed() throws {
        try withStore { store, calendar in
            let hour = Self.date(2026, 9, 17, 18, 0, calendar: calendar)
            try store.record(Self.sample(remaining: 80, at: hour.addingTimeInterval(5 * 60)))
            try store.record(Self.sample(remaining: 75, at: hour.addingTimeInterval(20 * 60)))
            try store.record(Self.sample(remaining: 71.5, at: hour.addingTimeInterval(40 * 60)))
            let record = try #require(
                try store.hourRecords(
                    service: .kimi,
                    metricKey: "monthly",
                    from: hour,
                    to: hour.addingTimeInterval(3600)
                ).first
            )
            #expect(record.opening == 80)
            #expect(record.closing == 71.5)
            #expect(abs(record.consumed - 8.5) < 0.0001)
            #expect(record.restored == 0)
            #expect(record.sampleCount == 3)
        }
    }

    @Test("remaining increases in the same hour accumulate as restored")
    func increasesAccumulateRestored() throws {
        try withStore { store, calendar in
            let hour = Self.date(2026, 9, 17, 18, 0, calendar: calendar)
            try store.record(Self.sample(remaining: 4, at: hour.addingTimeInterval(10 * 60)))
            try store.record(Self.sample(remaining: 100, at: hour.addingTimeInterval(11 * 60)))
            try store.record(Self.sample(remaining: 97, at: hour.addingTimeInterval(40 * 60)))
            let record = try #require(
                try store.hourRecords(
                    service: .kimi,
                    metricKey: "monthly",
                    from: hour,
                    to: hour.addingTimeInterval(3600)
                ).first
            )
            #expect(record.opening == 4)
            #expect(record.closing == 97)
            #expect(record.consumed == 3)
            #expect(record.restored == 96)
        }
    }

    @Test("tiny remaining jitter is not treated as consumption")
    func ignoresTinyJitter() throws {
        try withStore { store, calendar in
            let hour = Self.date(2026, 9, 17, 18, 0, calendar: calendar)
            try store.record(Self.sample(remaining: 80, at: hour.addingTimeInterval(60)))
            try store.record(Self.sample(remaining: 80.02, at: hour.addingTimeInterval(120)))
            let record = try #require(
                try store.hourRecords(
                    service: .kimi,
                    metricKey: "monthly",
                    from: hour,
                    to: hour.addingTimeInterval(3600)
                ).first
            )
            #expect(record.consumed == 0)
            #expect(record.restored == 0)
            #expect(record.closing == 80.02)
            #expect(record.sampleCount == 2)
        }
    }

    @Test("samples in different hours stay on separate rows")
    func splitsHours() throws {
        try withStore { store, calendar in
            try store.record(Self.sample(remaining: 80, at: Self.date(2026, 9, 17, 18, 50, calendar: calendar)))
            try store.record(Self.sample(remaining: 78, at: Self.date(2026, 9, 17, 19, 5, calendar: calendar)))
            let records = try store.hourRecords(
                service: .kimi,
                metricKey: "monthly",
                from: Self.date(2026, 9, 17, 18, 0, calendar: calendar),
                to: Self.date(2026, 9, 17, 20, 0, calendar: calendar)
            )
            #expect(records.map(\.consumed) == [0, 2])
            #expect(records.map(\.opening) == [80, 80])
            #expect(records.map(\.closing) == [80, 78])
        }
    }

    @Test("services and metrics do not collide")
    func isolatesServicesAndMetrics() throws {
        try withStore { store, calendar in
            let at = Self.date(2026, 9, 17, 18, 10, calendar: calendar)
            try store.record(Self.sample(service: .kimi, metricKey: "monthly", remaining: 80, at: at))
            try store.record(Self.sample(service: .gpt, metricKey: "weekly", remaining: 40, at: at))
            try store.record(Self.sample(service: .gpt, metricKey: "5h", remaining: 20, at: at))
            #expect(
                try store.hourRecords(
                    service: .kimi,
                    from: at,
                    to: at.addingTimeInterval(3600)
                ).map(\.metricKey) == ["monthly"]
            )
            #expect(
                try store.hourRecords(
                    service: .gpt,
                    from: at,
                    to: at.addingTimeInterval(3600)
                ).map(\.metricKey) == ["5h", "weekly"]
            )
        }
    }

    @Test("day week and month aggregates sum hourly consumed")
    func aggregatesBuckets() throws {
        try withStore { store, calendar in
            try store.record(Self.sample(remaining: 90, at: Self.date(2026, 9, 14, 10, 0, calendar: calendar)))
            try store.record(Self.sample(remaining: 85, at: Self.date(2026, 9, 14, 10, 30, calendar: calendar)))
            try store.record(Self.sample(remaining: 85, at: Self.date(2026, 9, 17, 8, 0, calendar: calendar)))
            try store.record(Self.sample(remaining: 80, at: Self.date(2026, 9, 17, 8, 20, calendar: calendar)))
            try store.record(Self.sample(remaining: 80, at: Self.date(2026, 9, 18, 9, 0, calendar: calendar)))
            try store.record(Self.sample(remaining: 79, at: Self.date(2026, 9, 18, 9, 15, calendar: calendar)))

            let from = Self.date(2026, 9, 14, 0, 0, calendar: calendar)
            let to = Self.date(2026, 9, 19, 0, 0, calendar: calendar)
            let days = try store.aggregatedRecords(
                service: .kimi,
                metricKey: "monthly",
                from: from,
                to: to,
                bucket: .day
            )
            #expect(days.map(\.consumed) == [5, 5, 1])
            #expect(days.map(\.periodStart) == [
                Self.date(2026, 9, 14, 0, 0, calendar: calendar),
                Self.date(2026, 9, 17, 0, 0, calendar: calendar),
                Self.date(2026, 9, 18, 0, 0, calendar: calendar)
            ])

            let weeks = try store.aggregatedRecords(
                service: .kimi,
                metricKey: "monthly",
                from: from,
                to: to,
                bucket: .week
            )
            #expect(weeks.count == 1)
            #expect(weeks[0].consumed == 11)
            #expect(
                weeks[0].periodStart
                    == QuotaHistoryClock.bucketStart(
                        .week,
                        of: Self.date(2026, 9, 14, 0, 0, calendar: calendar),
                        calendar: calendar
                    )
            )

            let months = try store.aggregatedRecords(
                service: .kimi,
                metricKey: "monthly",
                from: from,
                to: to,
                bucket: .month
            )
            #expect(months.map(\.consumed) == [11])
            #expect(months[0].opening == 90)
            #expect(months[0].closing == 79)
        }
    }

    @Test("reopening the sqlite file keeps hourly rows")
    func persistsAcrossReopen() throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("quota-history.sqlite")
        let calendar = Self.calendar
        let captured = Self.date(2026, 9, 17, 18, 10, calendar: calendar)

        do {
            let store = QuotaHistoryStore(databaseURL: url, calendar: calendar)
            try store.record(Self.sample(remaining: 64, at: captured))
            try store.record(Self.sample(remaining: 60, at: captured.addingTimeInterval(120)))
            store.close()
        }

        let reopened = QuotaHistoryStore(databaseURL: url, calendar: calendar)
        defer { reopened.close() }
        let record = try #require(
            try reopened.hourRecords(
                service: .kimi,
                metricKey: "monthly",
                from: captured,
                to: captured.addingTimeInterval(3600)
            ).first
        )
        #expect(record.consumed == 4)
        #expect(record.sampleCount == 2)
        let permissions = try #require(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        #expect(permissions.intValue & 0o777 == 0o600)
    }

    @Test("canonical-only queries skip non-capsule series")
    func canonicalOnlyFilter() throws {
        try withStore { store, calendar in
            let at = Self.date(2026, 9, 17, 18, 10, calendar: calendar)
            try store.record(
                Self.sample(service: .gpt, metricKey: "weekly", remaining: 40, at: at, isCanonical: true)
            )
            try store.record(
                Self.sample(service: .gpt, metricKey: "5h", remaining: 20, at: at, isCanonical: false)
            )
            let canonical = try store.hourRecords(
                service: .gpt,
                canonicalOnly: true,
                from: at,
                to: at.addingTimeInterval(3600)
            )
            #expect(canonical.map(\.metricKey) == ["weekly"])
        }
    }

    @Test("GPT Cursor Kimi and DeepSeek publish independent history series")
    @MainActor
    func pluginsPublishHistoryPoints() {
        let gptSnapshot = QuotaSnapshot(
            source: "Codex OAuth",
            primary: QuotaWindow(label: "5h", used: 80, limit: 100, resetAt: nil),
            secondary: QuotaWindow(label: "weekly", used: 10, limit: 100, resetAt: nil),
            creditsRemaining: nil,
            creditsTotal: nil,
            updatedAt: .now,
            note: nil
        )
        let gptPoints = GPTQuotaStore.historyPoints(from: gptSnapshot)
        #expect(gptPoints.map(\.metricKey) == ["5h", "weekly"])
        #expect(abs((gptPoints.first { $0.metricKey == "5h" }?.remaining ?? 0) - 20) < 0.0001)
        #expect(gptPoints.first { $0.metricKey == "5h" }?.isCanonical == true)
        #expect(gptPoints.first { $0.metricKey == "weekly" }?.isCanonical == false)
        #expect(GPTQuotaStore.historyMetricKey(forWindowLabel: "7d") == "weekly")

        let kimiPoints = KimiQuotaStore.historyPoints(
            from: MembershipStats(usedPercent: 78.4, codeUsedPercent: 12, resetTime: nil, giftsCount: 0)
        )
        #expect(kimiPoints.count == 1)
        #expect(kimiPoints[0].metricKey == "monthly")
        #expect(abs(kimiPoints[0].remaining - 21.6) < 0.0001)
        #expect(kimiPoints[0].isCanonical)

        let cursorSnapshot = QuotaSnapshot(
            source: "Cursor",
            primary: QuotaWindow(label: "Total", used: 100, limit: 100, resetAt: nil),
            secondary: QuotaWindow(label: "Auto", used: 40, limit: 100, resetAt: nil),
            tertiary: QuotaWindow(label: "API", used: 100, limit: 100, resetAt: nil),
            creditsRemaining: nil,
            creditsTotal: nil,
            updatedAt: .now,
            note: nil
        )
        let cursorPoints = CursorQuotaStore.historyPoints(from: cursorSnapshot, selectedPool: .cursorModels)
        #expect(cursorPoints.map(\.metricKey) == ["cursorModels", "otherModels"])
        #expect(cursorPoints.first { $0.metricKey == "cursorModels" }?.remaining == 60)
        #expect(cursorPoints.first { $0.metricKey == "cursorModels" }?.isCanonical == true)
        #expect(cursorPoints.first { $0.metricKey == "otherModels" }?.remaining == 0)
        #expect(cursorPoints.first { $0.metricKey == "otherModels" }?.isCanonical == false)

        let deepseekPoints = DeepSeekQuotaStore.historyPoints(
            from: DeepSeekBalance(
                isAvailable: true,
                infos: [
                    DeepSeekBalanceInfo(
                        currency: "USD",
                        totalBalance: "1.25",
                        grantedBalance: "0",
                        toppedUpBalance: "1.25"
                    ),
                    DeepSeekBalanceInfo(
                        currency: "CNY",
                        totalBalance: "110.50",
                        grantedBalance: "10.00",
                        toppedUpBalance: "100.50"
                    )
                ]
            )
        )
        #expect(deepseekPoints.first { $0.metricKey == "CNY" }?.remaining == 110.5)
        #expect(deepseekPoints.first { $0.metricKey == "CNY" }?.isCanonical == true)
        #expect(deepseekPoints.first { $0.metricKey == "USD" }?.remaining == 1.25)
        #expect(deepseekPoints.first { $0.metricKey == "USD" }?.isCanonical == false)
        #expect(deepseekPoints.first { $0.metricKey == "CNY" }?.unit == .currency)

        #expect(UnimplementedQuotaService(kind: .zcode).reading.historyPoints.isEmpty)
    }

    @Test("hourly ledger groups newest first and formats consumed remaining")
    func hourlyLedgerGroupsAndFormats() throws {
        try withStore { store, calendar in
            let evening = Self.date(2026, 9, 17, 20, 10, calendar: calendar)
            let night = Self.date(2026, 9, 17, 21, 5, calendar: calendar)
            try store.record(Self.sample(remaining: 61.59, at: evening))
            try store.record(Self.sample(remaining: 58.67, at: evening.addingTimeInterval(40 * 60)))
            try store.record(Self.sample(
                service: .gpt,
                metricKey: "weekly",
                remaining: 3,
                at: evening
            ))
            try store.record(Self.sample(remaining: 58.67, at: night))
            try store.record(Self.sample(remaining: 56.5, at: night.addingTimeInterval(20 * 60)))
            try store.record(Self.sample(
                service: .deepseek,
                metricKey: "CNY",
                remaining: 94.75,
                at: night,
                unit: .currency
            ))

            let records = try store.hourRecords(
                from: Self.date(2026, 9, 17, 0, 0, calendar: calendar),
                to: Self.date(2026, 9, 18, 0, 0, calendar: calendar)
            )
            let groups = QuotaHistoryLedger.grouped(records: records, calendar: calendar)
            #expect(groups.count == 1)
            #expect(groups[0].hours.map(\.hourStart) == [
                Self.date(2026, 9, 17, 21, 0, calendar: calendar),
                Self.date(2026, 9, 17, 20, 0, calendar: calendar)
            ])
            #expect(groups[0].hours[0].entries.map(\.service) == [.kimi, .deepseek])
            #expect(groups[0].hours[1].entries.map(\.service) == [.gpt, .kimi])

            let kimiNight = try #require(groups[0].hours[0].entries.first { $0.service == .kimi })
            #expect(QuotaHistoryLedger.entryTitle(kimiNight) == "Kimi · 月度")
            #expect(QuotaHistoryLedger.formatDelta(kimiNight) == "−2.17%")
            #expect(QuotaHistoryLedger.formatRemaining(kimiNight) == "余 56.5%")
            #expect(QuotaHistoryLedger.hourTitle(kimiNight.hourStart, calendar: calendar) == "21:00")
            #expect(
                QuotaHistoryLedger.dayTitle(
                    groups[0].dayStart,
                    now: Self.date(2026, 9, 17, 22, 0, calendar: calendar),
                    calendar: calendar
                ) == "今天"
            )

            let deepseek = try #require(groups[0].hours[0].entries.first { $0.service == .deepseek })
            #expect(QuotaHistoryLedger.entryTitle(deepseek) == "DeepSeek · 人民币")
            #expect(QuotaHistoryLedger.formatDelta(deepseek) == "¥0.00")
            #expect(QuotaHistoryLedger.formatRemaining(deepseek) == "余 ¥94.75")
        }
    }

    @Test("today ring uses percent shares and ignores currency and double windows")
    func todayRingUsesPercentShares() throws {
        try withStore { store, calendar in
            let day = Self.date(2026, 9, 18, 10, 0, calendar: calendar)
            try store.record(Self.sample(remaining: 60, at: day))
            try store.record(Self.sample(remaining: 50, at: day.addingTimeInterval(20 * 60)))
            try store.record(Self.sample(
                service: .gpt,
                metricKey: "5h",
                remaining: 40,
                at: day
            ))
            try store.record(Self.sample(
                service: .gpt,
                metricKey: "5h",
                remaining: 37,
                at: day.addingTimeInterval(15 * 60)
            ))
            try store.record(Self.sample(
                service: .gpt,
                metricKey: "weekly",
                remaining: 20,
                at: day
            ))
            try store.record(Self.sample(
                service: .gpt,
                metricKey: "weekly",
                remaining: 14,
                at: day.addingTimeInterval(15 * 60)
            ))
            try store.record(Self.sample(
                service: .deepseek,
                metricKey: "CNY",
                remaining: 90,
                at: day,
                unit: .currency
            ))
            try store.record(Self.sample(
                service: .deepseek,
                metricKey: "CNY",
                remaining: 80,
                at: day.addingTimeInterval(10 * 60),
                unit: .currency
            ))

            let records = try store.hourRecords(
                from: Self.date(2026, 9, 18, 0, 0, calendar: calendar),
                to: Self.date(2026, 9, 19, 0, 0, calendar: calendar)
            )
            let usage = QuotaHistoryAggregation.dailyPercentUsage(from: records, calendar: calendar)
            let today = calendar.startOfDay(for: day)
            #expect(usage[today]?[.kimi] == 10)
            #expect(usage[today]?[.gpt] == 6)
            #expect(usage[today]?[.deepseek] == nil)
            let slices = QuotaHistoryAggregation.slices(from: usage[today] ?? [:])
            #expect(slices.map(\.service) == [.gpt, .kimi])
            #expect(abs((slices.first { $0.service == .kimi }?.share ?? 0) - 10.0 / 16.0) < 0.0001)
            #expect(abs((slices.first { $0.service == .gpt }?.share ?? 0) - 6.0 / 16.0) < 0.0001)
        }
    }

    @Test("heatmap ranks more tools above a single heavy tool")
    func heatmapRanksToolCountFirst() {
        let oneTool = QuotaHistoryAggregation.intensity(
            toolsUsed: 1,
            consumedPercent: 20,
            maxConsumed: 20
        )
        let twoTools = QuotaHistoryAggregation.intensity(
            toolsUsed: 2,
            consumedPercent: 1,
            maxConsumed: 20
        )
        #expect(twoTools > oneTool)
        #expect(QuotaHistoryAggregation.intensity(toolsUsed: 0, consumedPercent: 0, maxConsumed: 20) == 0)
    }

    @Test("query range follows the selected lookback")
    func queryRangeFollowsPeriod() {
        let calendar = Self.calendar
        let now = Self.date(2026, 9, 18, 14, 22, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let day = QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: .day)
        #expect(day.from == today)
        #expect(day.to == now.addingTimeInterval(3600))

        let week = QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: .week)
        #expect(week.from == Self.date(2026, 9, 12, 0, 0, calendar: calendar))

        let month = QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: .month)
        #expect(month.from == Self.date(2026, 8, 18, 0, 0, calendar: calendar))

        let quarter = QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: .quarter)
        #expect(quarter.from == Self.date(2026, 6, 18, 0, 0, calendar: calendar))

        let year = QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: .year)
        #expect(year.from == Self.date(2025, 9, 18, 0, 0, calendar: calendar))
    }

    @Test("week snapshot combines daily percent usage into the ring")
    func weekSnapshotCombinesDailyUsage() throws {
        try withStore { store, calendar in
            let yesterday = Self.date(2026, 9, 17, 16, 0, calendar: calendar)
            let todayMorning = Self.date(2026, 9, 18, 9, 0, calendar: calendar)
            try store.record(Self.sample(remaining: 80, at: yesterday))
            try store.record(Self.sample(remaining: 70, at: yesterday.addingTimeInterval(30 * 60)))
            try store.record(Self.sample(
                service: .cursor,
                metricKey: "cursorModels",
                remaining: 50,
                at: todayMorning
            ))
            try store.record(Self.sample(
                service: .cursor,
                metricKey: "cursorModels",
                remaining: 48,
                at: todayMorning.addingTimeInterval(20 * 60)
            ))
            try store.record(Self.sample(remaining: 70, at: todayMorning))
            try store.record(Self.sample(remaining: 66, at: todayMorning.addingTimeInterval(20 * 60)))

            let now = Self.date(2026, 9, 18, 14, 22, calendar: calendar)
            let range = QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: .week)
            let records = try store.hourRecords(from: range.from, to: range.to)
            let snapshot = QuotaHistoryAggregation.snapshot(
                records: records,
                now: now,
                calendar: calendar,
                period: .week
            )
            #expect(Set(snapshot.slices.map(\.service)) == [.kimi, .cursor])
            #expect(snapshot.slices.first { $0.service == .kimi }?.consumedPercent == 14)
            #expect(snapshot.slices.first { $0.service == .cursor }?.consumedPercent == 2)
            if case .days(let days) = snapshot.heat {
                #expect(days.count == 7)
                #expect(days.filter { $0.kind == .active }.count >= 2)
            } else {
                Issue.record("week heatmap should be a day row")
            }
        }
    }

    @Test("day snapshot uses twenty four hour cells")
    func daySnapshotUsesHourCells() throws {
        try withStore { store, calendar in
            let morning = Self.date(2026, 9, 18, 9, 0, calendar: calendar)
            try store.record(Self.sample(remaining: 70, at: morning))
            try store.record(Self.sample(remaining: 66, at: morning.addingTimeInterval(20 * 60)))
            let now = Self.date(2026, 9, 18, 14, 22, calendar: calendar)
            let range = QuotaHistoryAggregation.queryRange(now: now, calendar: calendar, period: .day)
            let records = try store.hourRecords(from: range.from, to: range.to)
            let snapshot = QuotaHistoryAggregation.snapshot(
                records: records,
                now: now,
                calendar: calendar,
                period: .day
            )
            #expect(snapshot.slices.map(\.service) == [.kimi])
            if case .hours(let hours) = snapshot.heat {
                #expect(hours.count == 24)
                #expect(hours.filter { $0.kind == .future }.allSatisfy { $0.dayStart > now })
                #expect(hours.filter { $0.kind == .future }.count >= 9)
                let nine = hours.first { calendar.component(.hour, from: $0.dayStart) == 9 }
                #expect(nine?.kind == .active)
                #expect(nine?.toolsUsed == 1)
            } else {
                Issue.record("day heatmap should be hours")
            }
        }
    }

    @Test("recorder writes new successful readings and ignores stubs")
    @MainActor
    func recorderWritesSuccessfulReadings() throws {
        try withStore { store, calendar in
            let recorder = QuotaHistoryRecorder(store: store)
            let kimi = HistoryFakePlugin(kind: .kimi)
            let stub = HistoryFakePlugin(kind: .zcode, isImplemented: false)
            let captured = Self.date(2026, 9, 17, 18, 20, calendar: calendar)
            kimi.publish(remaining: 88, at: captured)
            stub.publish(remaining: 1, at: captured)
            recorder.capture([kimi, stub])
            recorder.capture([kimi, stub])
            #expect(recorder.revision == 1)

            let records = try store.hourRecords(
                service: .kimi,
                metricKey: "monthly",
                from: captured,
                to: captured.addingTimeInterval(3600)
            )
            #expect(records.count == 1)
            #expect(records[0].closing == 88)
            #expect(records[0].sampleCount == 1)
            #expect(
                try store.hourRecords(
                    service: .zcode,
                    from: captured,
                    to: captured.addingTimeInterval(3600)
                ).isEmpty
            )

            kimi.publish(remaining: 84, at: captured.addingTimeInterval(60))
            recorder.capture([kimi])
            let updated = try #require(
                try store.hourRecords(
                    service: .kimi,
                    metricKey: "monthly",
                    from: captured,
                    to: captured.addingTimeInterval(3600)
                ).first
            )
            #expect(updated.consumed == 4)
            #expect(updated.sampleCount == 2)
            #expect(recorder.revision == 2)
        }
    }

    @Test("recorder attached to the registry captures the next plugin publish")
    @MainActor
    func recorderAttachCapturesPluginPublish() async throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let calendar = Self.calendar
        let store = QuotaHistoryStore(
            databaseURL: directory.appendingPathComponent("quota-history.sqlite"),
            calendar: calendar
        )
        defer { store.close() }
        let recorder = QuotaHistoryRecorder(store: store)
        let fake = HistoryFakePlugin(kind: .deepseek)
        let registry = QuotaServiceRegistry(plugins: [fake])
        recorder.attach(to: registry)

        let captured = Self.date(2026, 9, 17, 18, 20, calendar: calendar)
        fake.publish(
            remaining: 12.5,
            at: captured,
            metricKey: "CNY",
            unit: .currency
        )
        await Self.waitForMainRunLoop()
        await Self.waitForMainRunLoop()

        let records = try store.hourRecords(
            service: .deepseek,
            metricKey: "CNY",
            from: captured,
            to: captured.addingTimeInterval(3600)
        )
        #expect(records.count == 1)
        #expect(records[0].closing == 12.5)
        #expect(records[0].unit == .currency)
        recorder.detach()
    }

    private func withStore(
        _ body: (QuotaHistoryStore, Calendar) throws -> Void
    ) throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let calendar = Self.calendar
        let store = QuotaHistoryStore(
            databaseURL: directory.appendingPathComponent("quota-history.sqlite"),
            calendar: calendar
        )
        defer { store.close() }
        try body(store, calendar)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    private static func sample(
        service: ServiceKind = .kimi,
        metricKey: String = "monthly",
        remaining: Double,
        at capturedAt: Date,
        unit: QuotaHistoryUnit = .percent,
        isCanonical: Bool = true
    ) -> QuotaHistorySample {
        QuotaHistorySample(
            service: service,
            metricKey: metricKey,
            remaining: remaining,
            unit: unit,
            isCanonical: isCanonical,
            capturedAt: capturedAt
        )
    }

    private static func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-history-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @MainActor
    private static func waitForMainRunLoop() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }
}

@MainActor
final class HistoryFakePlugin: ObservableObject, QuotaServicePlugin {
    let kind: ServiceKind
    let isImplemented: Bool
    @Published var reading: QuotaServiceReading
    var isRefreshing = false

    init(kind: ServiceKind, isImplemented: Bool = true) {
        self.kind = kind
        self.isImplemented = isImplemented
        self.reading = QuotaServiceReading()
    }

    func start() {}
    func stop() {}
    func refresh() {}

    func publish(
        remaining: Double,
        at date: Date,
        metricKey: String = "monthly",
        unit: QuotaHistoryUnit = .percent
    ) {
        reading = QuotaServiceReading(
            remainingPercent: unit == .percent ? Int(remaining.rounded()) : nil,
            lastUpdated: date,
            historyPoints: [
                QuotaHistoryPoint(
                    metricKey: metricKey,
                    remaining: remaining,
                    unit: unit,
                    isCanonical: true
                )
            ]
        )
    }
}
