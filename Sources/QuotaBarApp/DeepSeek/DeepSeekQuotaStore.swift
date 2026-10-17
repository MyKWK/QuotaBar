import Foundation

// MARK: - DeepSeek quota collector
//
// Prepaid API balance (not a membership percent). The shell renders the
// formatted currency headline; this store never invents a remaining %.

@MainActor
final class DeepSeekQuotaStore: ObservableObject, QuotaServicePlugin {
    let kind: ServiceKind = .deepseek
    typealias FetchHandler = @Sendable (String) async -> Result<DeepSeekBalance, DeepSeekClientError>
    typealias EnvironmentProvider = @Sendable () -> [String: String]

    @Published private(set) var balance: DeepSeekBalance?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    let credentialStore: KimiCredentialStore
    private let fetchHandler: FetchHandler
    private let environment: EnvironmentProvider
    private var timer: Timer?
    private var consecutiveFailures = 0
    private var started = false
    private(set) var refreshTask: Task<Void, Never>?

    init(
        credentialStore: KimiCredentialStore = KimiCredentialStore(),
        environment: @escaping EnvironmentProvider = { ProcessInfo.processInfo.environment },
        fetch: FetchHandler? = nil
    ) {
        self.credentialStore = credentialStore
        self.environment = environment
        if let fetch {
            self.fetchHandler = fetch
        } else {
            let client = DeepSeekBalanceClient()
            self.fetchHandler = { apiKey in
                await client.fetch(apiKey: apiKey)
            }
        }
    }

    var reading: QuotaServiceReading {
        var details: [QuotaServiceDetail] = []
        var caption: String?
        var headline: String?
        var warningLevel: QuotaWarningLevel?

        if let balance {
            if let primary = balance.primary {
                headline = DeepSeekPayloadParser.formattedAmount(primary.totalBalance, currency: primary.currency)
                warningLevel = DeepSeekPayloadParser.warningLevel(for: balance)

                if balance.infos.count > 1 {
                    for info in balance.infos {
                        details.append(QuotaServiceDetail(
                            label: "\(DeepSeekPayloadParser.currencyLabel(info.currency))余额",
                            value: DeepSeekPayloadParser.formattedAmount(info.totalBalance, currency: info.currency)
                        ))
                    }
                }
                details.append(QuotaServiceDetail(
                    label: "赠金",
                    value: DeepSeekPayloadParser.formattedAmount(primary.grantedBalance, currency: primary.currency)
                ))
                details.append(QuotaServiceDetail(
                    label: "充值",
                    value: DeepSeekPayloadParser.formattedAmount(primary.toppedUpBalance, currency: primary.currency)
                ))
            }
            details.append(QuotaServiceDetail(
                label: "账户状态",
                value: balance.isAvailable ? "可调用 API" : "余额不足"
            ))
            caption = balance.isAvailable ? nil : "当前余额不足以发起新的 API 调用"
        } else {
            caption = hasConfiguration ? "等待首次刷新…" : "尚未配置 API Key"
        }

        return QuotaServiceReading(
            remainingPercent: nil,
            headline: headline,
            placeholderHeadline: "--",
            headlineKind: .balance,
            warningLevel: warningLevel,
            metricTitle: "账户余额",
            caption: caption,
            details: details,
            lastUpdated: lastUpdated,
            lastError: lastError,
            setup: Self.setup,
            origin: Self.origin(balance: balance, headline: headline),
            externalQuotaURL: URL(string: "https://platform.deepseek.com/usage"),
            externalQuotaURLTitle: "打开 DeepSeek 用量页",
            historyPoints: Self.historyPoints(from: balance)
        )
    }

    static func historyPoints(from balance: DeepSeekBalance?) -> [QuotaHistoryPoint] {
        guard let balance else { return [] }
        let primaryCurrency = balance.primary?.currency
        return balance.infos.compactMap { info in
            guard let remaining = DeepSeekPayloadParser.numericAmount(info.totalBalance) else {
                return nil
            }
            let currency = info.currency.uppercased()
            return QuotaHistoryPoint(
                metricKey: currency,
                remaining: remaining,
                unit: .currency,
                isCanonical: primaryCurrency.map {
                    $0.caseInsensitiveCompare(info.currency) == .orderedSame
                } ?? false
            )
        }
    }

    static let setup = QuotaSetupGuide(
        paragraphs: [
            "DeepSeek 按余额计费，不是会员套餐百分比。查询用的是官方 API Key，不是网页登录 token。",
            "在 DeepSeek 开放平台创建 API Key 后，可选择把变量名告诉 QuotaBar，或把 Key 原文保存在本机凭据文件里。"
        ],
        actions: [
            QuotaSetupAction(
                title: "打开 DeepSeek 创建 API Key",
                url: URL(string: "https://platform.deepseek.com/api_keys")!
            )
        ]
    )

    static func origin(balance: DeepSeekBalance?, headline: String?) -> QuotaBalanceOrigin {
        var currentReading: String?
        if let headline, let primary = balance?.primary {
            let label = DeepSeekPayloadParser.currencyLabel(primary.currency)
            currentReading = "本次取的是 \(label) 总可用余额，因此显示 \(headline)。"
        }
        return QuotaBalanceOrigin(
            paragraphs: [
                "数字来自 DeepSeek 官方查询余额接口 GET https://api.deepseek.com/user/balance，用 API Key 作为 Bearer Token。",
                "胶囊显示总可用余额（未过期赠金 + 充值）。同时有人民币和美元时优先显示人民币；赠金和充值只作明细，不改这个数字。",
                "这不是会员剩余百分比。QuotaBar 只在本机展示；除向 DeepSeek 官方接口查询余额外，不会把 Key 发到其他地方。"
            ],
            currentReading: currentReading
        )
    }

    var hasConfiguration: Bool {
        guard case .success(let credentials) = credentialStore.loadDeepSeek() else { return false }
        return !credentials.isEmpty
    }

    var keySource: DeepSeekKeySource {
        (try? credentialStore.loadDeepSeek().get())?.source ?? .environmentVariable
    }

    var configuredEnvironmentVariableName: String? {
        guard case .success(let credentials) = credentialStore.loadDeepSeek(),
              credentials.source == .environmentVariable else { return nil }
        return credentials.environmentVariableName
    }

    var hasStoredAPIKey: Bool {
        guard case .success(let credentials) = credentialStore.loadDeepSeek() else { return false }
        return credentials.source == .storedKey && DeepSeekAPIKeyResolver.normalizedAPIKey(credentials.apiKey) != nil
    }

    func start() {
        guard !started else { return }
        started = true
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
        started = false
    }

    @discardableResult
    func setEnvironmentVariableName(_ rawName: String) -> String? {
        guard let name = DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName(rawName) else {
            return "环境变量名无效；请使用字母、数字或下划线，例如 DEEPSEEK_API_KEY"
        }
        if let error = credentialStore.saveDeepSeek(
            DeepSeekCredentials(source: .environmentVariable, environmentVariableName: name)
        ) {
            return error
        }
        consecutiveFailures = 0
        lastError = nil
        refresh()
        return nil
    }

    @discardableResult
    func setStoredAPIKey(_ rawKey: String) -> String? {
        guard DeepSeekAPIKeyResolver.normalizedAPIKey(rawKey) != nil else {
            return "没有输入 API Key"
        }
        if let error = credentialStore.saveDeepSeek(
            DeepSeekCredentials(source: .storedKey, apiKey: rawKey)
        ) {
            return error
        }
        consecutiveFailures = 0
        lastError = nil
        refresh()
        return nil
    }

    @discardableResult
    func clearCredentials() -> String? {
        if let error = credentialStore.deleteDeepSeek() {
            return error
        }
        balance = nil
        lastUpdated = nil
        lastError = "尚未配置 DeepSeek API Key"
        return nil
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        let credentials: DeepSeekCredentials
        switch credentialStore.loadDeepSeek() {
        case .failure(let error):
            isRefreshing = false
            lastError = error.message
            consecutiveFailures += 1
            scheduleNext(after: failureDelay())
            return
        case .success(let value):
            credentials = value
        }

        switch DeepSeekAPIKeyResolver.resolve(credentials, environment: environment()) {
        case .failure(let error):
            isRefreshing = false
            lastError = error.message
            consecutiveFailures += 1
            scheduleNext(after: failureDelay())
        case .success(let apiKey):
            refreshTask = Task { [weak self, fetchHandler] in
                let result = await fetchHandler(apiKey)
                guard !Task.isCancelled, let self else { return }
                self.isRefreshing = false
                switch result {
                case .success(let value):
                    self.balance = value
                    self.lastUpdated = Date()
                    self.lastError = nil
                    self.consecutiveFailures = 0
                    self.scheduleNext(after: 60)
                case .failure(let error):
                    self.lastError = error.message
                    self.consecutiveFailures += 1
                    let delay = error.retryAfter ?? self.failureDelay()
                    self.scheduleNext(after: delay)
                }
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
        return max(60, min(15 * 60, 30 * pow(2, Double(exponent))))
    }
}
