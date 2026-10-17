import AppKit
import Foundation
import Testing
@testable import QuotaBarApp

@Suite("Status bar services")
struct StatusBarServicesPresenterTests {
    @Test("formats a single-line Logo percent capsule per service")
    func formatsSingleLinePercent() {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(service: .kimi, remainingPercent: 100),
            StatusBarServiceInput(service: .gpt, remainingPercent: 87)
        ])

        #expect(entries.count == 2)
        #expect(entries[0].text == "100%")
        #expect(entries[0].hasData)
        #expect(entries[0].level == .normal)
        #expect(!entries[0].text.contains("\n"))
        #expect(entries[1].text == "87%")
    }

    @Test("shows a placeholder instead of a fabricated number when a service has no source")
    func showsPlaceholderWithoutData() {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(service: .gpt, remainingPercent: nil),
            StatusBarServiceInput(service: .zcode, remainingPercent: nil)
        ])

        #expect(entries.allSatisfy { $0.text == "--%" && !$0.hasData && $0.level == .normal })
    }

    @Test("applies low and exhausted thresholds")
    func appliesWarningThresholds() {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(service: .kimi, remainingPercent: 20),
            StatusBarServiceInput(service: .gpt, remainingPercent: 0),
            StatusBarServiceInput(service: .zcode, remainingPercent: 21)
        ])

        #expect(entries[0].level == .low)
        #expect(entries[1].level == .exhausted)
        #expect(entries[2].level == .normal)
    }

    @Test("clamps out-of-range percents")
    func clampsPercents() {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(service: .kimi, remainingPercent: 140),
            StatusBarServiceInput(service: .kimi, remainingPercent: -5)
        ])

        #expect(entries[0].text == "100%")
        #expect(entries[1].text == "0%")
        #expect(entries[1].level == .exhausted)
    }

    @Test("tooltip summarizes each service without inventing data")
    func tooltipText() {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(service: .kimi, remainingPercent: 64),
            StatusBarServiceInput(service: .gpt, remainingPercent: nil),
            StatusBarServiceInput(service: .cursor, remainingPercent: 61)
        ])

        let tooltip = StatusBarServicesPresenter.tooltip(for: entries)
        #expect(tooltip.contains("Kimi 剩余 64%"))
        #expect(tooltip.contains("GPT 暂无额度数据"))
        #expect(tooltip.contains("Cursor 剩余 61%"))

        #expect(!StatusBarServicesPresenter.tooltip(for: []).isEmpty)
    }

    @Test("formats a prepaid balance without inventing a percent")
    func formatsBalanceHeadline() {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(
                service: .deepseek,
                remainingPercent: nil,
                headline: "¥110.00",
                placeholderHeadline: "--",
                headlineKind: .balance,
                warningLevel: .normal
            ),
            StatusBarServiceInput(
                service: .deepseek,
                remainingPercent: nil,
                headline: nil,
                placeholderHeadline: "--",
                headlineKind: .balance
            )
        ])

        #expect(entries[0].text == "¥110.00")
        #expect(entries[0].hasData)
        #expect(entries[0].level == .normal)
        #expect(!entries[0].text.contains("%"))
        #expect(entries[1].text == "--")
        #expect(!entries[1].hasData)

        let tooltip = StatusBarServicesPresenter.tooltip(for: entries)
        #expect(tooltip.contains("DeepSeek 余额 ¥110.00"))
        #expect(tooltip.contains("DeepSeek 暂无额度数据"))
        #expect(!tooltip.contains("剩余 --"))
    }

    @Test("exhausted prepaid balance uses the plugin warning level")
    func balanceWarningLevel() {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(
                service: .deepseek,
                remainingPercent: nil,
                headline: "¥0.00",
                placeholderHeadline: "--",
                headlineKind: .balance,
                warningLevel: .exhausted
            )
        ])
        #expect(entries[0].level == .exhausted)
        #expect(entries[0].text == "¥0.00")
    }
}

@Suite("Menu bar logo contrast")
struct MenuBarLogoContrastTests {
    @Test("ink is black on a light menu bar and white on a dark one")
    func inkFollowsMenuBarAppearance() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        #expect(!MenuBarContrast.isDark(light))
        #expect(MenuBarContrast.isDark(dark))

        let lightInk = try #require(MenuBarContrast.inkColor(in: light).usingColorSpace(.deviceRGB))
        let darkInk = try #require(MenuBarContrast.inkColor(in: dark).usingColorSpace(.deviceRGB))
        #expect(lightInk.redComponent < 0.25)
        #expect(darkInk.redComponent > 0.75)
    }

    @Test("every service logo stays visible when tinted for light and dark bars")
    @MainActor
    func serviceLogosVisibleOnBothContrasts() throws {
        for service in ServiceKind.allCases {
            for color in [NSColor.black, NSColor.white] {
                let image = ServiceLogoImage.image(for: service, size: 26, color: color)
                #expect(visiblePixelCount(image) > 0)
            }
        }
    }

    @Test("white-source and dark-source logos both take the requested ink")
    @MainActor
    func rasterizerRecolorsLightAndDarkSources() throws {
        let blackKimi = ServiceLogoImage.image(for: .kimi, size: 32, color: .black)
        let whiteCursor = ServiceLogoImage.image(for: .cursor, size: 32, color: .white)
        #expect(averageVisibleLuminance(blackKimi) < 0.25)
        #expect(averageVisibleLuminance(whiteCursor) > 0.75)
    }

    @Test("status item image is a baked bitmap so replicants do not relayout a live view tree")
    @MainActor
    func statusItemImageIsBakedBitmap() throws {
        let entries = StatusBarServicesPresenter.entries(for: [
            StatusBarServiceInput(service: .kimi, remainingPercent: 100),
            StatusBarServiceInput(service: .gpt, remainingPercent: 42)
        ])
        let display = StatusBarServicesDisplay(items: entries)
        let appearance = try #require(NSAppearance(named: .aqua))
        let image = StatusBarServicesRenderer.makeImage(
            display: display,
            fallbackIcon: NSImage(size: NSSize(width: 17, height: 17)),
            appearance: appearance,
            scale: 2
        )

        #expect(image.representations.contains { $0 is NSBitmapImageRep })
        #expect(!image.isTemplate)
        #expect(image.size.height == StatusBarServicesRenderer.preferredHeight)
        #expect(abs(image.size.width - display.contentWidth) < 0.5)
        #expect(visiblePixelCount(image) > 0)
    }

    @Test("empty status item image still has visible fallback pixels")
    @MainActor
    func emptyStatusItemUsesFallbackIcon() throws {
        let appearance = try #require(NSAppearance(named: .darkAqua))
        let fallback = Branding.makeMenuBarIcon(size: 17)
        let image = StatusBarServicesRenderer.makeImage(
            display: nil,
            fallbackIcon: fallback,
            appearance: appearance,
            scale: 2
        )
        #expect(image.representations.contains { $0 is NSBitmapImageRep })
        #expect(visiblePixelCount(image) > 0)
    }
}

// These tests mutate the shared UserDefaults key, so they must not run in parallel
// with each other (swift-testing runs tests concurrently by default).
@Suite("Menu bar service preferences", .serialized)
struct MenuBarServicesPreferenceTests {
    private static let key = "QuotaBar.MenuBarVisibleServices"

    @Test("absent preference defaults to all services")
    func defaultsToAllServices() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: Self.key)
        defer {
            if let original {
                defaults.set(original, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }

        defaults.removeObject(forKey: Self.key)
        #expect(AppPreferencesStore.menuBarVisibleServices == Set(ServiceKind.allCases))
        #expect(AppPreferencesStore.menuBarVisibleServices.count == ServiceKind.allCases.count)
        #expect(ServiceKind.menuBarOrder.contains(.cursor))
        #expect(ServiceKind.menuBarOrder.contains(.deepseek))
    }

    @Test("roundtrips an explicit subset and honors an empty selection")
    func roundtripsSubset() {
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: Self.key)
        defer {
            if let original {
                defaults.set(original, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }

        AppPreferencesStore.setMenuBarVisibleServices([.kimi])
        #expect(AppPreferencesStore.menuBarVisibleServices == [.kimi])

        AppPreferencesStore.setMenuBarVisibleServices([])
        #expect(AppPreferencesStore.menuBarVisibleServices.isEmpty)

        defaults.set(["kimi", "unknown-service"], forKey: Self.key)
        #expect(AppPreferencesStore.menuBarVisibleServices == [.kimi])
    }

    @Test("enables Cursor once for users who had the previous all-services set")
    func migratesLegacyAllServicesToIncludeCursor() {
        let defaults = UserDefaults.standard
        let originalVisible = defaults.object(forKey: Self.key)
        let originalMigrated = defaults.object(forKey: "QuotaBar.MigratedCursorMenuBarService")
        defer {
            if let originalVisible {
                defaults.set(originalVisible, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
            if let originalMigrated {
                defaults.set(originalMigrated, forKey: "QuotaBar.MigratedCursorMenuBarService")
            } else {
                defaults.removeObject(forKey: "QuotaBar.MigratedCursorMenuBarService")
            }
        }

        defaults.removeObject(forKey: "QuotaBar.MigratedCursorMenuBarService")
        defaults.set(["kimi", "gpt", "zcode"], forKey: Self.key)
        #expect(AppPreferencesStore.menuBarVisibleServices == [.kimi, .gpt, .zcode, .cursor])
    }

    @Test("enables DeepSeek once for users who had the previous all-services set")
    func migratesLegacyAllServicesToIncludeDeepSeek() {
        let defaults = UserDefaults.standard
        let originalVisible = defaults.object(forKey: Self.key)
        let originalMigrated = defaults.object(forKey: "QuotaBar.MigratedDeepSeekMenuBarService")
        defer {
            if let originalVisible {
                defaults.set(originalVisible, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
            if let originalMigrated {
                defaults.set(originalMigrated, forKey: "QuotaBar.MigratedDeepSeekMenuBarService")
            } else {
                defaults.removeObject(forKey: "QuotaBar.MigratedDeepSeekMenuBarService")
            }
        }

        defaults.removeObject(forKey: "QuotaBar.MigratedDeepSeekMenuBarService")
        defaults.set(["kimi", "gpt", "zcode", "cursor"], forKey: Self.key)
        #expect(AppPreferencesStore.menuBarVisibleServices == [.kimi, .gpt, .zcode, .cursor, .deepseek])
    }

    @Test("Cursor capsule pool defaults to internal and roundtrips")
    func cursorQuotaPoolRoundtrips() {
        let key = "QuotaBar.CursorQuotaPool"
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: key)
        defer {
            if let original {
                defaults.set(original, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        #expect(AppPreferencesStore.cursorQuotaPool == .cursorModels)

        AppPreferencesStore.setCursorQuotaPool(.otherModels)
        #expect(AppPreferencesStore.cursorQuotaPool == .otherModels)

        defaults.set("not-a-pool", forKey: key)
        #expect(AppPreferencesStore.cursorQuotaPool == .cursorModels)
    }

    @Test("AppState toggles services and persists them")
    @MainActor
    func appStateTogglesServices() {
        let defaults = UserDefaults.standard
        // Deterministic baseline: absent key means "all services visible". Do not
        // rely on (or restore) ambient values — earlier runs may have left any
        // state behind in the test process's persisted defaults.
        defaults.removeObject(forKey: Self.key)
        defer { defaults.removeObject(forKey: Self.key) }

        let state = AppState()
        #expect(state.menuBarVisibleServices == Set(ServiceKind.allCases))
        state.setServiceVisibleInMenuBar(.zcode, false)
        #expect(!state.isServiceVisibleInMenuBar(.zcode))
        #expect(AppPreferencesStore.menuBarVisibleServices == Set(ServiceKind.allCases).subtracting([.zcode]))

        state.setServiceVisibleInMenuBar(.zcode, true)
        #expect(state.isServiceVisibleInMenuBar(.zcode))

        // Unimplemented plugins (ZCode) report no remaining percent.
        #expect(state.menuBarRemainingPercent(for: .zcode) == nil)
    }
}

@Suite("GPT local usage")
struct GPTQuotaStoreTests {
    @Test("uses the same bottleneck remaining percentage as Codex")
    @MainActor
    func derivesBottleneckPercent() {
        let snapshot = QuotaSnapshot(
            source: "Codex OAuth",
            primary: QuotaWindow(label: "5h", used: 10, limit: 100, resetAt: nil),
            secondary: QuotaWindow(label: "weekly", used: 91, limit: 100, resetAt: nil),
            creditsRemaining: nil,
            creditsTotal: nil,
            updatedAt: .now,
            note: nil
        )
        #expect(GPTQuotaStore.remainingPercent(from: snapshot) == 9)
        #expect(GPTQuotaStore.metricTitle(from: snapshot) == "每周剩余")
        #expect(
            GPTQuotaStore.origin(snapshot: snapshot, remainingPercent: 9).currentReading
                == "本次取的是「每周」窗口，因此显示 9%。"
        )
    }

    @Test("names the 5-hour window when it is tighter than weekly")
    @MainActor
    func namesFiveHourBottleneck() {
        let snapshot = QuotaSnapshot(
            source: "Codex OAuth",
            primary: QuotaWindow(label: "5h", used: 80, limit: 100, resetAt: nil),
            secondary: QuotaWindow(label: "weekly", used: 10, limit: 100, resetAt: nil),
            creditsRemaining: nil,
            creditsTotal: nil,
            updatedAt: .now,
            note: nil
        )
        #expect(GPTQuotaStore.remainingPercent(from: snapshot) == 20)
        #expect(GPTQuotaStore.metricTitle(from: snapshot) == "5 小时剩余")
        #expect(
            GPTQuotaStore.origin(snapshot: snapshot, remainingPercent: 20).currentReading
                == "本次取的是「5 小时」窗口，因此显示 20%。"
        )
    }
}

@Suite("Cursor quota store", .serialized)
struct CursorQuotaStoreTests {
    @Test("internal pool remaining matches Cursor Models used percent")
    @MainActor
    func remainingMatchesInternalPool() throws {
        let snapshot = try CursorProvider().parseCurrentPeriodUsageForTesting(
            [
                "membershipType": "team",
                "planUsage": [
                    "totalSpend": 10000,
                    "limit": 10000,
                    "totalPercentUsed": 100,
                    "autoPercentUsed": 40,
                    "apiPercentUsed": 100
                ]
            ] as [String: Any],
            membershipType: "team"
        )

        #expect(snapshot.primary?.label == "Total")
        #expect(snapshot.secondary?.label == "Auto")
        #expect(snapshot.secondary?.used == 40)
        #expect(snapshot.tertiary?.label == "API")
        #expect(snapshot.tertiary?.used == 100)
        // Team Total is exhausted by Other Models (0% remaining). The capsule
        // must follow the selected pool instead of that Total bar.
        #expect(CursorQuotaStore.remainingPercent(from: snapshot, pool: .cursorModels) == 60)
        #expect(CursorQuotaStore.remainingPercent(from: snapshot, pool: .otherModels) == 0)
    }

    @Test("missing Auto/API windows do not invent a remaining percent")
    @MainActor
    func missingPoolWindowIsNil() {
        let snapshot = QuotaSnapshot(
            source: "Cursor",
            primary: QuotaWindow(label: "Total", used: 25, limit: 100, resetAt: nil),
            secondary: QuotaWindow(label: "On-demand", used: 90, limit: 100, resetAt: nil),
            creditsRemaining: nil,
            creditsTotal: nil,
            updatedAt: .now,
            note: nil
        )
        #expect(CursorQuotaStore.remainingPercent(from: snapshot, pool: .cursorModels) == nil)
        #expect(CursorQuotaStore.remainingPercent(from: snapshot, pool: .otherModels) == nil)
    }

    @Test("successful refresh publishes the selected pool remaining percent")
    @MainActor
    func refreshPublishesRemainingPercent() async {
        let snapshot = QuotaSnapshot(
            source: "Cursor",
            primary: QuotaWindow(label: "Total", used: 100, limit: 100, resetAt: nil),
            secondary: QuotaWindow(label: "Auto", used: 40, limit: 100, resetAt: nil),
            tertiary: QuotaWindow(label: "API", used: 100, limit: 100, resetAt: nil),
            creditsRemaining: nil,
            creditsTotal: nil,
            updatedAt: .now,
            note: nil
        )
        let defaults = UserDefaults.standard
        let originalPool = defaults.object(forKey: "QuotaBar.CursorQuotaPool")
        defer {
            if let originalPool {
                defaults.set(originalPool, forKey: "QuotaBar.CursorQuotaPool")
            } else {
                defaults.removeObject(forKey: "QuotaBar.CursorQuotaPool")
            }
        }

        let store = CursorQuotaStore(pool: .cursorModels) { snapshot }
        store.refresh()
        await store.refreshTask?.value
        #expect(store.remainingPercent == 60)
        #expect(store.usedPercent == 40)
        #expect(store.reading.details.contains { $0.label == "内部额度剩余" && $0.value == "60%" })
        #expect(store.reading.details.contains { $0.label == "外部额度剩余" && $0.value == "0%" })
        #expect(store.lastError == nil)
        store.selectedPool = .otherModels
        #expect(store.remainingPercent == 0)
        #expect(store.usedPercent == 100)
        #expect(store.reading.metricTitle == "外部额度剩余")
        #expect(AppPreferencesStore.cursorQuotaPool == .otherModels)
        store.stop()
    }

    @Test("failed refresh keeps the placeholder and surfaces the error")
    @MainActor
    func failureKeepsPlaceholder() async {
        let store = CursorQuotaStore(pool: .cursorModels) {
            throw ProviderError.loginRequired(tool: .cursor, message: "未找到 Cursor 登录状态")
        }
        store.refresh()
        await store.refreshTask?.value
        #expect(store.remainingPercent == nil)
        #expect(store.usedPercent == nil)
        #expect(store.lastError == "无法读取本机 Cursor 登录用量；请确认已在 Cursor 中登录后重试")
        store.stop()
    }
}

@Suite("Kimi quota store")
struct KimiQuotaStoreTests {
    @Test("successful refresh publishes stats and clears errors")
    @MainActor
    func refreshPublishesStats() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = KimiQuotaStore(
            credentialStore: KimiCredentialStore(
                filePath: directory.appendingPathComponent("c.json").path
            )
        ) {
            .success(MembershipStats(usedPercent: 22, codeUsedPercent: nil, resetTime: nil, giftsCount: 0))
        }

        store.refresh()
        await store.refreshTask?.value
        #expect(store.remainingPercent == 78)
        #expect(store.reading.remainingPercent == 78)
        #expect(store.reading.details.contains(where: { $0.label == "已用" }))
        #expect(store.statusBarText == "78%")
        #expect(store.lastError == nil)
        #expect(store.lastUpdated != nil)
        store.stop()
    }

    @Test("failed refresh keeps the placeholder and surfaces the error")
    @MainActor
    func failureKeepsPlaceholder() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = KimiQuotaStore(
            credentialStore: KimiCredentialStore(
                filePath: directory.appendingPathComponent("c.json").path
            )
        ) {
            .failure(KimiClientError(.credentials, "尚未设置 Kimi 网页登录凭据"))
        }

        store.refresh()
        await store.refreshTask?.value
        #expect(store.remainingPercent == nil)
        #expect(store.statusBarText == "--%")
        #expect(store.lastError == "尚未设置 Kimi 网页登录凭据")
        store.stop()
    }

    @Test("rejects API keys and non-kimi app tokens without storing them")
    @MainActor
    func rejectsWrongTokenKinds() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-store-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let credentialStore = KimiCredentialStore(
            filePath: directory.appendingPathComponent("c.json").path
        )
        let store = KimiQuotaStore(credentialStore: credentialStore) {
            .failure(KimiClientError(.credentials, "unused"))
        }

        #expect(store.setCredentials(accessToken: "sk-test-key", refreshToken: "") != nil)
        #expect(!store.hasAccessToken)

        #expect(store.setCredentials(accessToken: "", refreshToken: "") == "没有输入新凭据")

        func base64URL(_ string: String) -> String {
            Data(string.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        let otherAppToken = [
            base64URL(#"{"alg":"none"}"#),
            base64URL(#"{"app_id":"other"}"#),
            "sig"
        ].joined(separator: ".")
        #expect(store.setCredentials(accessToken: otherAppToken, refreshToken: "") != nil)
        #expect(!store.hasAccessToken)
    }
}

private func visiblePixelCount(_ image: NSImage) -> Int {
    guard let representation = TintedTemplateImage.bitmapRepresentation(of: image) else {
        return 0
    }
    var count = 0
    for y in 0 ..< representation.pixelsHigh {
        for x in 0 ..< representation.pixelsWide {
            if (representation.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                count += 1
            }
        }
    }
    return count
}

private func averageVisibleLuminance(_ image: NSImage) -> CGFloat {
    guard let representation = TintedTemplateImage.bitmapRepresentation(of: image) else {
        return -1
    }
    var total: CGFloat = 0
    var count: CGFloat = 0
    for y in 0 ..< representation.pixelsHigh {
        for x in 0 ..< representation.pixelsWide {
            guard let pixel = representation.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  pixel.alphaComponent > 0.2 else {
                continue
            }
            total += pixel.redComponent * 0.2126 + pixel.greenComponent * 0.7152 + pixel.blueComponent * 0.0722
            count += 1
        }
    }
    return count == 0 ? -1 : total / count
}
