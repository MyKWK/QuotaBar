import Foundation

enum AppPreferencesStore {
    private static let refreshOnOpenKey = "QuotaBar.RefreshOnOpenEnabled"
    private static let recommendationStrategyKey = "QuotaBar.RecommendationStrategy"
    private static let menuBarVisibleToolsKey = "QuotaBar.MenuBarVisibleTools"
    private static let menuBarVisibleServicesKey = "QuotaBar.MenuBarVisibleServices"
    private static let cursorMenuBarMigratedKey = "QuotaBar.MigratedCursorMenuBarService"
    private static let deepSeekMenuBarMigratedKey = "QuotaBar.MigratedDeepSeekMenuBarService"
    private static let cursorQuotaPoolKey = "QuotaBar.CursorQuotaPool"
    private static let ignoredUpdateVersionKey = "QuotaBar.IgnoredUpdateVersion"
    private static let quotaNotificationsEnabledKey = "QuotaBar.QuotaNotificationsEnabled"
    private static let quotaNotificationThresholdKey = "QuotaBar.QuotaNotificationThreshold"

    static let quotaNotificationThresholdOptions: [Double] = [0.10, 0.20, 0.30]

    static var refreshOnOpenEnabled: Bool {
        bool(forKey: refreshOnOpenKey, defaultValue: true)
    }

    static var quotaNotificationsEnabled: Bool {
        bool(forKey: quotaNotificationsEnabledKey, defaultValue: false)
    }

    static func setQuotaNotificationsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: quotaNotificationsEnabledKey)
    }

    static var quotaNotificationThreshold: Double {
        let stored = UserDefaults.standard.double(forKey: quotaNotificationThresholdKey)
        guard quotaNotificationThresholdOptions.contains(stored) else { return 0.20 }
        return stored
    }

    static func setQuotaNotificationThreshold(_ threshold: Double) {
        UserDefaults.standard.set(threshold, forKey: quotaNotificationThresholdKey)
    }

    static var menuBarVisibleTools: Set<ToolKind> {
        // Absent key (first launch) means show everything; an explicitly empty
        // saved array is honored as "show none".
        guard let raw = UserDefaults.standard.array(forKey: menuBarVisibleToolsKey) as? [String] else {
            return Set(ToolKind.allCases)
        }
        return Set(raw.compactMap(ToolKind.init(rawValue:)))
    }

    static func setMenuBarVisibleTools(_ tools: Set<ToolKind>) {
        UserDefaults.standard.set(tools.map(\.rawValue), forKey: menuBarVisibleToolsKey)
    }

    // Capsule toggles on the General settings page (Kimi / GPT / Cursor / DeepSeek / ZCode). Same
    // semantics as menuBarVisibleTools: absent key means show everything; an
    // explicitly empty saved array is honored as "show none".
    static var menuBarVisibleServices: Set<ServiceKind> {
        migrateCursorMenuBarServiceIfNeeded()
        migrateDeepSeekMenuBarServiceIfNeeded()
        guard let raw = UserDefaults.standard.array(forKey: menuBarVisibleServicesKey) as? [String] else {
            return Set(ServiceKind.allCases)
        }
        return Set(raw.compactMap(ServiceKind.init(rawValue:)))
    }

    static func setMenuBarVisibleServices(_ services: Set<ServiceKind>) {
        UserDefaults.standard.set(services.map(\.rawValue), forKey: menuBarVisibleServicesKey)
    }

    /// Which Cursor included-usage pool the menu-bar capsule shows.
    /// Absent key means internal Cursor Models (Grok / Composer).
    static var cursorQuotaPool: CursorQuotaPool {
        guard let raw = UserDefaults.standard.string(forKey: cursorQuotaPoolKey),
              let pool = CursorQuotaPool(rawValue: raw) else {
            return .cursorModels
        }
        return pool
    }

    static func setCursorQuotaPool(_ pool: CursorQuotaPool) {
        UserDefaults.standard.set(pool.rawValue, forKey: cursorQuotaPoolKey)
    }

    /// Users who already persisted the previous default trio (Kimi / GPT / ZCode)
    /// should pick up Cursor once. Custom subsets are left unchanged.
    private static func migrateCursorMenuBarServiceIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: cursorMenuBarMigratedKey) == nil else { return }
        defaults.set(true, forKey: cursorMenuBarMigratedKey)

        guard let raw = defaults.array(forKey: menuBarVisibleServicesKey) as? [String] else {
            return
        }
        let legacyDefault = Set(["kimi", "gpt", "zcode"])
        guard Set(raw) == legacyDefault else { return }
        defaults.set(raw + [ServiceKind.cursor.rawValue], forKey: menuBarVisibleServicesKey)
    }

    /// Users who already persisted the previous all-services set (Kimi / GPT /
    /// Cursor / ZCode) should pick up DeepSeek once. Custom subsets stay as-is.
    private static func migrateDeepSeekMenuBarServiceIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: deepSeekMenuBarMigratedKey) == nil else { return }
        defaults.set(true, forKey: deepSeekMenuBarMigratedKey)

        guard let raw = defaults.array(forKey: menuBarVisibleServicesKey) as? [String] else {
            return
        }
        let previousDefault = Set(["kimi", "gpt", "zcode", "cursor"])
        guard Set(raw) == previousDefault else { return }
        defaults.set(raw + [ServiceKind.deepseek.rawValue], forKey: menuBarVisibleServicesKey)
    }

    static var recommendationStrategy: AccountRecommendationStrategy {
        guard let rawValue = UserDefaults.standard.string(forKey: recommendationStrategyKey),
              let strategy = AccountRecommendationStrategy(rawValue: rawValue) else {
            return .preventWaste
        }
        return strategy
    }

    static var ignoredUpdateVersion: String? {
        UserDefaults.standard.string(forKey: ignoredUpdateVersionKey)
    }

    static func isUpdateVersionIgnored(_ version: String) -> Bool {
        ignoredUpdateVersion == version
    }

    static func setRefreshOnOpenEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: refreshOnOpenKey)
    }

    static func setRecommendationStrategy(_ strategy: AccountRecommendationStrategy) {
        UserDefaults.standard.set(strategy.rawValue, forKey: recommendationStrategyKey)
    }

    static func setIgnoredUpdateVersion(_ version: String?) {
        if let version {
            UserDefaults.standard.set(version, forKey: ignoredUpdateVersionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ignoredUpdateVersionKey)
        }
    }

    private static func bool(forKey key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}
