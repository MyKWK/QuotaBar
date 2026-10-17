import Combine
import Foundation
import Testing
@testable import QuotaBarApp

@MainActor
final class FakeQuotaService: ObservableObject, QuotaServicePlugin {
    let kind: ServiceKind
    let isImplemented: Bool
    @Published var reading: QuotaServiceReading
    @Published var isRefreshing = false

    init(kind: ServiceKind, remainingPercent: Int?, isImplemented: Bool = true) {
        self.kind = kind
        self.isImplemented = isImplemented
        self.reading = QuotaServiceReading(
            remainingPercent: remainingPercent,
            metricTitle: "剩余额度"
        )
    }

    func start() {}
    func stop() {}
    func refresh() {
        reading.remainingPercent = (reading.remainingPercent ?? 0) + 1
    }
}

@Suite("Quota service plugins")
struct QuotaServicePluginTests {
    @Test("default registry covers every ServiceKind")
    @MainActor
    func defaultRegistryCoversAllKinds() {
        let registry = QuotaServiceRegistry()
        for kind in ServiceKind.allCases {
            #expect(registry.plugin(for: kind).kind == kind)
        }
        #expect(registry.plugin(for: .gpt) is GPTQuotaStore)
        #expect(registry.plugin(for: .kimi) is KimiQuotaStore)
        #expect(registry.plugin(for: .cursor) is CursorQuotaStore)
        #expect(registry.plugin(for: .deepseek) is DeepSeekQuotaStore)
        #expect(registry.plugin(for: .zcode) is UnimplementedQuotaService)
        #expect(!registry.plugin(for: .zcode).isImplemented)
        #expect(registry.remainingPercent(for: .zcode) == nil)
        #expect(registry.plugin(for: .deepseek).reading.headlineKind == .balance)
    }

    @Test("missing plugins fall back to an unimplemented stub")
    @MainActor
    func missingPluginFallsBackToStub() {
        let registry = QuotaServiceRegistry(plugins: [
            FakeQuotaService(kind: .gpt, remainingPercent: 10)
        ])
        #expect(registry.plugin(for: .gpt) is FakeQuotaService)
        #expect(registry.remainingPercent(for: .gpt) == 10)
        #expect(registry.plugin(for: .zcode) is UnimplementedQuotaService)
        #expect(registry.remainingPercent(for: .zcode) == nil)
        #expect(registry.plugin(for: .kimi) is UnimplementedQuotaService)
        #expect(registry.plugin(for: .cursor) is UnimplementedQuotaService)
    }

    @Test("the shell reads remaining percent from the registered plugin")
    @MainActor
    func shellReadsInjectedPlugin() {
        let registry = QuotaServiceRegistry(plugins: [
            FakeQuotaService(kind: .zcode, remainingPercent: 42)
        ])
        let state = AppState(quotaServices: registry)
        #expect(state.menuBarRemainingPercent(for: .zcode) == 42)
        #expect(state.menuBarRemainingPercent(for: .gpt) == nil)
    }

    @Test("GPT and Cursor collectors publish a standard reading")
    @MainActor
    func liveCollectorsExposeStandardReading() {
        #expect(GPTQuotaStore().kind == .gpt)
        #expect(GPTQuotaStore().reading.metricTitle == "Codex 额度")
        #expect(CursorQuotaStore(pool: .cursorModels).kind == .cursor)
        #expect(CursorQuotaStore(pool: .cursorModels).reading.metricTitle == "内部额度剩余")
        #expect(CursorQuotaStore(pool: .otherModels).reading.metricTitle == "外部额度剩余")
        #expect(KimiQuotaStore().kind == .kimi)
        #expect(KimiQuotaStore().reading.metricTitle == "剩余额度")
        #expect(DeepSeekQuotaStore().kind == .deepseek)
        #expect(DeepSeekQuotaStore().reading.metricTitle == "账户余额")
        #expect(DeepSeekQuotaStore().reading.headlineKind == .balance)
        #expect(DeepSeekQuotaStore().reading.remainingPercent == nil)
        #expect(DeepSeekQuotaStore().reading.placeholderHeadline == "--")
    }

    @Test("each plugin explains how its remaining percent is derived")
    @MainActor
    func eachPluginPublishesADistinctOrigin() {
        let gpt = GPTQuotaStore().reading.origin
        let kimi = KimiQuotaStore().reading.origin
        let cursor = CursorQuotaStore(pool: .cursorModels).reading.origin
        let deepseek = DeepSeekQuotaStore().reading.origin
        let zcode = UnimplementedQuotaService(kind: .zcode).reading.origin

        #expect(gpt?.title == "余额怎么来的")
        #expect(kimi?.title == "余额怎么来的")
        #expect(cursor?.title == "余额怎么来的")
        #expect(deepseek?.title == "余额怎么来的")
        #expect(zcode?.title == "余额怎么来的")

        let gptText = gpt?.paragraphs.joined(separator: " ") ?? ""
        let kimiText = kimi?.paragraphs.joined(separator: " ") ?? ""
        let cursorText = cursor?.paragraphs.joined(separator: " ") ?? ""
        let deepseekText = deepseek?.paragraphs.joined(separator: " ") ?? ""
        let zcodeText = zcode?.paragraphs.joined(separator: " ") ?? ""

        #expect(gptText.contains("还剩最少"))
        #expect(gptText.contains("5 小时"))
        #expect(kimiText.contains("会员额度"))
        #expect(kimiText.contains("100 −"))
        #expect(cursorText.contains("内部额度"))
        #expect(cursorText.contains("外部额度"))
        #expect(cursorText.contains("Total"))
        #expect(deepseekText.contains("/user/balance"))
        #expect(deepseekText.contains("总可用余额"))
        #expect(deepseekText.contains("不是会员剩余百分比"))
        #expect(zcodeText.contains("还没有真实数据源"))
        #expect(zcodeText.contains("--%"))
        #expect(gptText != kimiText)
        #expect(kimiText != cursorText)
        #expect(cursorText != deepseekText)
        #expect(cursor?.currentReading?.contains("内部额度") == true)
        #expect(
            CursorQuotaStore.origin(pool: .otherModels, remainingPercent: 0).currentReading
                == "当前展示「外部额度」，对应 Other Models 窗口，因此显示 0%。"
        )
        #expect(
            KimiQuotaStore.origin(
                stats: MembershipStats(usedPercent: 78.4, codeUsedPercent: 12, resetTime: nil, giftsCount: 0),
                remainingPercent: 22
            ).currentReading == "本次月度套餐已用 78.4%，因此剩余 22%。"
        )
    }

    @Test("each plugin publishes a setup guide for obtaining quota")
    @MainActor
    func eachPluginPublishesSetupGuide() {
        let gpt = GPTQuotaStore().reading.setup
        let kimi = KimiQuotaStore().reading.setup
        let cursor = CursorQuotaStore(pool: .cursorModels).reading.setup
        let deepseek = DeepSeekQuotaStore().reading.setup
        let zcode = UnimplementedQuotaService(kind: .zcode).reading.setup

        #expect(gpt?.title == "获取方式")
        #expect(kimi?.title == "获取方式")
        #expect(cursor?.title == "获取方式")
        #expect(deepseek?.title == "获取方式")
        #expect(zcode?.title == "获取方式")

        #expect(gpt?.paragraphs.joined().contains("Codex") == true)
        #expect(gpt?.actions.isEmpty == true)

        #expect(kimi?.actions.first?.title.contains("access_token") == true)
        #expect(kimi?.actions.first?.url.absoluteString == "https://www.kimi.com")
        #expect(kimi?.paragraphs.joined().contains("Local Storage") == true)

        #expect(cursor?.paragraphs.joined().contains("Cursor") == true)
        #expect(deepseek?.actions.first?.url.absoluteString == "https://platform.deepseek.com/api_keys")
        #expect(deepseek?.paragraphs.joined().contains("API Key") == true)
        #expect(zcode?.paragraphs.joined().contains("尚未接入") == true)
    }

    @Test("registry forwards plugin changes")
    @MainActor
    func registryForwardsPluginChanges() async {
        let fake = FakeQuotaService(kind: .zcode, remainingPercent: 10)
        let registry = QuotaServiceRegistry(plugins: [fake])
        var forwarded = false
        let cancellable = registry.objectWillChange.sink { forwarded = true }
        fake.refresh()
        #expect(registry.remainingPercent(for: .zcode) == 11)
        #expect(forwarded)
        _ = cancellable
    }
}
