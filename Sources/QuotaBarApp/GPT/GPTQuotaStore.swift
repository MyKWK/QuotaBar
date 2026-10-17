import Foundation

/// Read-only Codex/ChatGPT collector. Maps the existing `CodexProvider` usage
/// payload into `QuotaServiceReading` for the shared shell.
@MainActor
final class GPTQuotaStore: ObservableObject, QuotaServicePlugin {
    let kind: ServiceKind = .gpt

    @Published private(set) var snapshot: QuotaSnapshot?
    @Published private(set) var remainingPercent: Int?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    var reading: QuotaServiceReading {
        QuotaServiceReading(
            remainingPercent: remainingPercent,
            metricTitle: Self.metricTitle(from: snapshot),
            caption: snapshot?.planName.flatMap { $0.isEmpty ? nil : $0 },
            lastUpdated: lastUpdated,
            lastError: lastError,
            setup: Self.setup,
            origin: Self.origin(snapshot: snapshot, remainingPercent: remainingPercent),
            historyPoints: Self.historyPoints(from: snapshot)
        )
    }

    private let provider: CodexProvider
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var started = false

    init(provider: CodexProvider = CodexProvider()) {
        self.provider = provider
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
        let provider = provider
        let path = (provider.activeAuthPath as NSString).expandingTildeInPath

        refreshTask = Task { [weak self] in
            let result: Result<QuotaSnapshot, Error>
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                guard let secret = String(data: data, encoding: .utf8) else {
                    throw ProviderError.credentialParsingFailed(tool: .codex)
                }
                result = .success(try await provider.fetchQuota(secret: secret))
            } catch {
                result = .failure(error)
            }

            guard !Task.isCancelled, let self else { return }
            self.isRefreshing = false
            switch result {
            case .success(let snapshot):
                self.snapshot = snapshot
                self.remainingPercent = Self.remainingPercent(from: snapshot)
                self.lastUpdated = Date()
                self.lastError = self.remainingPercent == nil ? "当前账户没有可显示的额度窗口" : nil
            case .failure:
                self.snapshot = nil
                self.remainingPercent = nil
                self.lastError = "无法读取本机 Codex 登录用量；请确认 Codex 已登录后重试"
            }
            self.scheduleNextRefresh()
        }
    }

    static let setup = QuotaSetupGuide(
        paragraphs: [
            "GPT 额度来自本机已经登录的 Codex，不需要粘贴网页 token。",
            "请先在本机完成 Codex / ChatGPT 登录，然后点右上角「立即刷新」。"
        ]
    )

    static func remainingPercent(from snapshot: QuotaSnapshot) -> Int? {
        guard let ratio = snapshot.statusBarMetric?.ratio else { return nil }
        return Int((min(max(ratio, 0), 1) * 100).rounded())
    }

    static func historyPoints(from snapshot: QuotaSnapshot?) -> [QuotaHistoryPoint] {
        guard let snapshot else { return [] }
        let windows = snapshot.accountWindows(for: .codex).filter { $0.limit > 0 }
        let canonicalKey = snapshot.statusBarMetric.map { historyMetricKey(forWindowLabel: $0.title) }
        return windows.map { window in
            let key = historyMetricKey(forWindowLabel: window.label)
            return QuotaHistoryPoint(
                metricKey: key,
                remaining: window.remainingPercent,
                unit: .percent,
                isCanonical: key == canonicalKey
            )
        }
    }

    static func historyMetricKey(forWindowLabel label: String) -> String {
        switch label.lowercased() {
        case "5h":
            return "5h"
        case "weekly", "7d", "7 days", "week":
            return "weekly"
        default:
            return label.lowercased()
        }
    }

    static func metricTitle(from snapshot: QuotaSnapshot?) -> String {
        guard let title = snapshot?.statusBarMetric?.title else {
            return "Codex 额度"
        }
        return "\(windowDisplayName(title))剩余"
    }

    static func origin(snapshot: QuotaSnapshot?, remainingPercent: Int?) -> QuotaBalanceOrigin {
        var currentReading: String?
        if let metric = snapshot?.statusBarMetric {
            let name = windowDisplayName(metric.title)
            if let remainingPercent {
                currentReading = "本次取的是「\(name)」窗口，因此显示 \(remainingPercent)%。"
            } else {
                currentReading = "本次本应取「\(name)」窗口，但没有可用的剩余比例。"
            }
        }
        return QuotaBalanceOrigin(
            paragraphs: [
                "QuotaBar 不登录 ChatGPT 网页，也不导入或切换本机 Codex 账号。",
                "它只读取本机已经登录的 Codex 会话，再用这份会话查询 Codex 官方用量接口。",
                "胶囊显示账号级限速窗口里还剩最少的那一档。Codex 通常同时有 5 小时窗口和每周窗口：哪个更紧，菜单栏就显示哪个。",
                "数字 = 该窗口剩余量 ÷ 上限，再四舍五入成整数。模型专属额度、代码审查和点数不决定这个数字。"
            ],
            currentReading: currentReading
        )
    }

    static func windowDisplayName(_ title: String) -> String {
        switch title.lowercased() {
        case "5h":
            return "5 小时"
        case "weekly", "7d", "7 days", "week":
            return "每周"
        default:
            return title
        }
    }

    private func scheduleNextRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }
}
