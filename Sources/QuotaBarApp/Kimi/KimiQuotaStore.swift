import Foundation

// MARK: - Kimi quota collector
//
// `QuotaServicePlugin` for Kimi membership: periodic refresh with backoff,
// credential updates, and the standard `QuotaServiceReading` the shell renders.
// Tokens pass through `KimiCredentialStore` only; nothing here logs them.

@MainActor
final class KimiQuotaStore: ObservableObject, QuotaServicePlugin {
    let kind: ServiceKind = .kimi
    typealias FetchHandler = () async -> Result<MembershipStats, KimiClientError>

    @Published private(set) var stats: MembershipStats?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    let credentialStore: KimiCredentialStore
    private let fetchHandler: FetchHandler
    private var config = KimiQuotaConfig()
    private var timer: Timer?
    private var consecutiveFailures = 0
    private var started = false
    /// The in-flight refresh, kept so tests (and future callers) can await it.
    private(set) var refreshTask: Task<Void, Never>?

    init(
        credentialStore: KimiCredentialStore = KimiCredentialStore(),
        fetch: FetchHandler? = nil
    ) {
        self.credentialStore = credentialStore
        if let fetch {
            self.fetchHandler = fetch
        } else {
            let client = KimiMembershipClient(credentialStore: credentialStore)
            self.fetchHandler = {
                await withCheckedContinuation { continuation in
                    client.fetch { result in
                        continuation.resume(returning: result)
                    }
                }
            }
        }
    }

    var remainingPercent: Int? {
        stats.map { Int($0.remainingPercent.rounded()) }
    }

    var reading: QuotaServiceReading {
        var details: [QuotaServiceDetail] = []
        var caption: String?
        if let stats {
            details.append(QuotaServiceDetail(label: "已用", value: String(format: "%.1f%%", stats.usedPercent)))
            if let code = stats.codeUsedPercent {
                details.append(QuotaServiceDetail(label: "Code 占月度", value: String(format: "%.1f%%", code)))
            }
            if let resetTime = stats.resetTime, !resetTime.isEmpty {
                details.append(QuotaServiceDetail(label: "重置时间", value: resetTime))
            }
            if stats.giftsCount > 0 {
                details.append(QuotaServiceDetail(label: "赠送额度", value: "\(stats.giftsCount) 项"))
            }
        } else {
            caption = hasAccessToken || hasRefreshToken ? "等待首次刷新…" : "尚未设置登录凭据"
        }
        return QuotaServiceReading(
            remainingPercent: remainingPercent,
            metricTitle: "剩余额度",
            caption: caption,
            details: details,
            lastUpdated: lastUpdated,
            lastError: lastError,
            setup: Self.setup,
            origin: Self.origin(stats: stats, remainingPercent: remainingPercent),
            externalQuotaURL: URL(string: "https://www.kimi.com/membership/subscription?tab=quota"),
            externalQuotaURLTitle: "打开 Kimi 额度页",
            historyPoints: Self.historyPoints(from: stats)
        )
    }

    static func historyPoints(from stats: MembershipStats?) -> [QuotaHistoryPoint] {
        guard let stats else { return [] }
        return [
            QuotaHistoryPoint(
                metricKey: "monthly",
                remaining: stats.remainingPercent,
                unit: .percent,
                isCanonical: true
            )
        ]
    }

    static let setup = QuotaSetupGuide(
        paragraphs: [
            "需要的是 kimi.com 网页登录 token，不是 Kimi Code / API Key。",
            "打开 Kimi 并登录后，在浏览器开发者工具的 Application / 存储 → Local Storage 中复制 access_token 和 refresh_token，粘贴到下方配置。"
        ],
        actions: [
            QuotaSetupAction(
                title: "打开 Kimi 获取 access_token",
                url: URL(string: "https://www.kimi.com")!
            )
        ]
    )

    static func origin(stats: MembershipStats?, remainingPercent: Int?) -> QuotaBalanceOrigin {
        var currentReading: String?
        if let stats {
            let used = String(format: "%.1f", stats.usedPercent)
            if let remainingPercent {
                currentReading = "本次月度套餐已用 \(used)%，因此剩余 \(remainingPercent)%。"
            } else {
                currentReading = "本次读到月度已用 \(used)%，但没有可显示的剩余百分比。"
            }
        }
        return QuotaBalanceOrigin(
            paragraphs: [
                "数字来自 Kimi 会员额度接口，不是 Kimi Code / API Key。",
                "胶囊百分比 = 100 − 月度套餐已用比例。Code 占月度和赠送额度只作参考，不会改这个剩余数字。"
            ],
            currentReading: currentReading
        )
    }

    /// Single-line text for the menu bar capsule: a real percentage when data
    /// exists, a clear placeholder otherwise (never a fabricated number).
    var statusBarText: String {
        remainingPercent.map { "\($0)%" } ?? "--%"
    }

    var hasAccessToken: Bool {
        guard case .success(let credentials) = credentialStore.load() else { return false }
        return !(credentials.accessToken?.isEmpty ?? true)
    }

    var hasRefreshToken: Bool {
        guard case .success(let credentials) = credentialStore.load() else { return false }
        return !(credentials.refreshToken?.isEmpty ?? true)
    }

    func start() {
        guard !started else { return }
        started = true
        config = KimiQuotaConfig.load(migratingTo: credentialStore)
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
        started = false
    }

    /// Validates and stores new credentials. Returns an error message on failure.
    /// The inputs are consumed and never logged or displayed back.
    @discardableResult
    func setCredentials(accessToken rawAccess: String, refreshToken rawRefresh: String) -> String? {
        let access = KimiQuotaConfig.normalizedBearerToken(rawAccess)
        let refreshSecret = KimiQuotaConfig.normalizedBearerToken(rawRefresh)
        guard access != nil || refreshSecret != nil else {
            return "没有输入新凭据"
        }
        if let access, access.lowercased().hasPrefix("sk-") {
            return "这里需要 Kimi 网页登录 token，不是 Kimi Code/API Key"
        }
        if let access, let appID = JWTClaims.appID(access), appID != "kimi" {
            return "access_token 的 app_id 不是 kimi，无法用于会员额度接口"
        }
        if let error = credentialStore.merge(accessToken: access, refreshToken: refreshSecret) {
            return error
        }
        consecutiveFailures = 0
        lastError = nil
        refresh()
        return nil
    }

    @discardableResult
    func clearCredentials() -> String? {
        if let error = credentialStore.delete() {
            return error
        }
        stats = nil
        lastUpdated = nil
        lastError = "尚未设置 Kimi 网页登录凭据"
        return nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        config = KimiQuotaConfig.load(migratingTo: credentialStore)

        refreshTask = Task { [weak self, fetchHandler] in
            let result = await fetchHandler()
            guard !Task.isCancelled, let self else { return }
            self.isRefreshing = false
            switch result {
            case .success(let value):
                self.stats = value
                self.lastUpdated = Date()
                self.lastError = nil
                self.consecutiveFailures = 0
                self.scheduleNext(after: self.config.refreshInterval)
            case .failure(let error):
                self.lastError = error.message
                self.consecutiveFailures += 1
                let delay = error.retryAfter ?? self.failureDelay()
                self.scheduleNext(after: delay)
            }
        }
    }

    private func scheduleNext(after delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: max(30, delay), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    private func failureDelay() -> TimeInterval {
        let exponent = min(max(consecutiveFailures - 1, 0), 5)
        return max(config.refreshInterval, min(15 * 60, 30 * pow(2, Double(exponent))))
    }
}
