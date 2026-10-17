import Foundation

/// Read-only Cursor IDE collector. Maps `CursorProvider` current-period usage
/// into `QuotaServiceReading` for the shared shell.
@MainActor
final class CursorQuotaStore: ObservableObject, QuotaServicePlugin {
    let kind: ServiceKind = .cursor
    typealias FetchHandler = () async throws -> QuotaSnapshot

    @Published var selectedPool: CursorQuotaPool {
        didSet {
            guard oldValue != selectedPool else { return }
            AppPreferencesStore.setCursorQuotaPool(selectedPool)
            applyDisplayedPercent()
        }
    }

    @Published private(set) var snapshot: QuotaSnapshot?
    @Published private(set) var remainingPercent: Int?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    private let fetchHandler: FetchHandler
    private var timer: Timer?
    private var started = false
    /// The in-flight refresh, kept so tests can await it.
    private(set) var refreshTask: Task<Void, Never>?

    init(
        provider: CursorProvider = CursorProvider(),
        pool: CursorQuotaPool? = nil,
        fetch: FetchHandler? = nil
    ) {
        self.selectedPool = pool ?? AppPreferencesStore.cursorQuotaPool
        if let fetch {
            self.fetchHandler = fetch
        } else {
            self.fetchHandler = {
                var secret = try await provider.importCurrentCredentials()
                if let refreshed = try? await provider.refreshSecretIfNeeded(secret) {
                    secret = refreshed
                }
                return try await provider.fetchQuota(secret: secret)
            }
        }
    }

    /// Used amount complementary to the capsule remaining percent, so
    /// "settings used 40%" and "remaining 60%" cannot drift by rounding.
    var usedPercent: Int? {
        remainingPercent.map { 100 - $0 }
    }

    var reading: QuotaServiceReading {
        var details: [QuotaServiceDetail] = []
        if let internalRemaining = snapshot.flatMap({ Self.remainingPercent(from: $0, pool: .cursorModels) }) {
            details.append(QuotaServiceDetail(label: "内部额度剩余", value: "\(internalRemaining)%"))
        }
        if let externalRemaining = snapshot.flatMap({ Self.remainingPercent(from: $0, pool: .otherModels) }) {
            details.append(QuotaServiceDetail(label: "外部额度剩余", value: "\(externalRemaining)%"))
        }
        if let periodEnd = snapshot?.periodEnd {
            details.append(
                QuotaServiceDetail(
                    label: "本周期结束",
                    value: periodEnd.formatted(date: .abbreviated, time: .omitted)
                )
            )
        }

        let captionParts = [
            snapshot?.planName.flatMap { $0.isEmpty ? nil : $0 },
            selectedPool.poolCaption
        ].compactMap { $0 }

        return QuotaServiceReading(
            remainingPercent: remainingPercent,
            metricTitle: selectedPool.metricTitle,
            caption: captionParts.isEmpty ? nil : captionParts.joined(separator: " · "),
            details: details,
            lastUpdated: lastUpdated,
            lastError: lastError,
            setup: Self.setup,
            origin: Self.origin(pool: selectedPool, remainingPercent: remainingPercent),
            externalQuotaURL: URL(string: "https://cursor.com/dashboard/usage"),
            externalQuotaURLTitle: "打开 Cursor 用量页",
            historyPoints: Self.historyPoints(from: snapshot, selectedPool: selectedPool)
        )
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

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        refreshTask = Task { [weak self, fetchHandler] in
            let result: Result<QuotaSnapshot, Error>
            do {
                result = .success(try await fetchHandler())
            } catch {
                result = .failure(error)
            }

            guard !Task.isCancelled, let self else { return }
            self.isRefreshing = false
            switch result {
            case .success(let snapshot):
                self.snapshot = snapshot
                self.lastUpdated = Date()
                self.applyDisplayedPercent()
            case .failure:
                self.snapshot = nil
                self.remainingPercent = nil
                self.lastError = "无法读取本机 Cursor 登录用量；请确认已在 Cursor 中登录后重试"
            }
            self.scheduleNextRefresh()
        }
    }

    static let setup = QuotaSetupGuide(
        paragraphs: [
            "Cursor 额度来自本机已经登录的 Cursor IDE，不需要粘贴网页 token。",
            "请先在 Cursor 中登录账号，然后点右上角「立即刷新」。"
        ]
    )

    static func origin(pool: CursorQuotaPool, remainingPercent: Int?) -> QuotaBalanceOrigin {
        var currentReading = "当前展示「\(pool.displayName)」，对应 \(pool.poolCaption) 窗口"
        if let remainingPercent {
            currentReading += "，因此显示 \(remainingPercent)%。"
        } else {
            currentReading += "；当前账户还没有这一池的用量数据。"
        }
        return QuotaBalanceOrigin(
            paragraphs: [
                "QuotaBar 只读取本机已经登录的 Cursor，拉取当前账单周期的套餐内用量，不会修改登录状态。",
                "套餐内有两池：内部额度对应 Cursor Models（Auto，如 Grok / Composer），外部额度对应 Other Models（API）。胶囊跟随本页所选的那一池：剩余 = 100 − 该池已用百分比。",
                "不会使用 Team 的美元 Total 条。那条经常被外部额度打满后显示 0%，即使内部额度还在。"
            ],
            currentReading: currentReading
        )
    }

    nonisolated static func historyPoints(
        from snapshot: QuotaSnapshot?,
        selectedPool: CursorQuotaPool
    ) -> [QuotaHistoryPoint] {
        guard let snapshot else { return [] }
        return CursorQuotaPool.allCases.compactMap { pool in
            guard let window = usageWindow(from: snapshot, pool: pool), window.limit > 0 else {
                return nil
            }
            return QuotaHistoryPoint(
                metricKey: pool.rawValue,
                remaining: window.remainingPercent,
                unit: .percent,
                isCanonical: pool == selectedPool
            )
        }
    }

    /// Remaining percent for the selected included-usage pool.
    /// Cursor Models (`Auto`) is internal; Other Models (`API`) is external.
    /// The Team dollar Total window is not used for the capsule — when Other
    /// Models is exhausted that Total bar reads 0% even if Cursor Models remain.
    nonisolated static func remainingPercent(
        from snapshot: QuotaSnapshot,
        pool: CursorQuotaPool = .cursorModels
    ) -> Int? {
        guard let window = usageWindow(from: snapshot, pool: pool), window.limit > 0 else {
            return nil
        }
        return Int(min(max(window.remainingPercent, 0), 100).rounded())
    }

    nonisolated static func usageWindow(
        from snapshot: QuotaSnapshot,
        pool: CursorQuotaPool
    ) -> QuotaWindow? {
        let windows = [snapshot.primary, snapshot.secondary, snapshot.tertiary]
            .compactMap { $0 } + snapshot.extraWindows
        return windows.first {
            $0.label.compare(pool.windowLabel, options: .caseInsensitive) == .orderedSame
        }
    }

    private func applyDisplayedPercent() {
        remainingPercent = snapshot.flatMap { Self.remainingPercent(from: $0, pool: selectedPool) }
        if snapshot != nil {
            lastError = remainingPercent == nil
                ? "当前账户没有可显示的\(selectedPool.displayName)"
                : nil
        }
    }

    private func scheduleNextRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }
}
