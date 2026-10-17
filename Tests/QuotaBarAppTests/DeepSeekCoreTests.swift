import Foundation
import Testing
@testable import QuotaBarApp

@Suite("DeepSeek balance")
struct DeepSeekPayloadParserTests {
    @Test("parses the official CNY example and prefers CNY over USD")
    func parsesOfficialExamplePreferringCNY() throws {
        let data = Data(#"""
        {
          "is_available": true,
          "balance_infos": [
            {
              "currency": "USD",
              "total_balance": "12.50",
              "granted_balance": "2.50",
              "topped_up_balance": "10.00"
            },
            {
              "currency": "CNY",
              "total_balance": "110.00",
              "granted_balance": "10.00",
              "topped_up_balance": "100.00"
            }
          ]
        }
        """#.utf8)

        let balance = try #require(try? DeepSeekPayloadParser.parse(data).get())
        #expect(balance.isAvailable)
        #expect(balance.infos.count == 2)
        #expect(balance.primary?.currency == "CNY")
        #expect(balance.primary?.totalBalance == "110.00")
        #expect(DeepSeekPayloadParser.formattedAmount("110.00", currency: "CNY") == "¥110.00")
        #expect(DeepSeekPayloadParser.warningLevel(for: balance) == .normal)
    }

    @Test("accepts camelCase keys")
    func parsesCamelCase() throws {
        let data = Data(#"""
        {"isAvailable":false,"balanceInfos":[{"currency":"USD","totalBalance":"0.00","grantedBalance":"0","toppedUpBalance":"0"}]}
        """#.utf8)
        let balance = try #require(try? DeepSeekPayloadParser.parse(data).get())
        #expect(!balance.isAvailable)
        #expect(balance.primary?.currency == "USD")
        #expect(DeepSeekPayloadParser.warningLevel(for: balance) == .exhausted)
        #expect(DeepSeekPayloadParser.formattedAmount("0.00", currency: "USD") == "$0.00")
    }

    @Test("fails when balance_infos is missing")
    func failsOnMissingInfos() {
        let data = Data(#"{"is_available":true}"#.utf8)
        switch DeepSeekPayloadParser.parse(data) {
        case .success:
            Issue.record("expected parsing to fail")
        case .failure(let error):
            #expect(error.kind == .payload)
        }
    }
}

@Suite("DeepSeek API key resolver")
struct DeepSeekAPIKeyResolverTests {
    @Test("normalizes environment variable names")
    func normalizesEnvironmentVariableNames() {
        #expect(DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName(" DEEPSEEK_API_KEY ") == "DEEPSEEK_API_KEY")
        #expect(DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName("$DEEPSEEK_API_KEY") == "DEEPSEEK_API_KEY")
        #expect(DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName("1ABC") == nil)
        #expect(DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName("HAS-DASH") == nil)
        #expect(DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName("   ") == nil)
    }

    @Test("resolves a stored key and an environment variable without echoing secrets")
    func resolvesSources() throws {
        let stored = DeepSeekCredentials(source: .storedKey, apiKey: "Bearer sk-stored")
        #expect(try DeepSeekAPIKeyResolver.resolve(stored, environment: [:]).get() == "sk-stored")

        let env = DeepSeekCredentials(source: .environmentVariable, environmentVariableName: "DEEPSEEK_API_KEY")
        #expect(try DeepSeekAPIKeyResolver.resolve(
            env,
            environment: ["DEEPSEEK_API_KEY": "  sk-from-env  "]
        ).get() == "sk-from-env")

        switch DeepSeekAPIKeyResolver.resolve(env, environment: [:]) {
        case .success:
            Issue.record("expected a missing-env failure")
        case .failure(let error):
            #expect(error.kind == .credentials)
            #expect(error.message.contains("DEEPSEEK_API_KEY"))
            #expect(!error.message.contains("sk-"))
        }
    }
}

@Suite("DeepSeek quota store")
struct DeepSeekQuotaStoreTests {
    @Test("successful refresh publishes a balance headline instead of a percent")
    @MainActor
    func refreshPublishesBalanceHeadline() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-deepseek-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let credentialStore = KimiCredentialStore(
            filePath: directory.appendingPathComponent("c.json").path
        )
        let store = DeepSeekQuotaStore(credentialStore: credentialStore, fetch: { _ in
            .success(DeepSeekBalance(
                isAvailable: true,
                infos: [
                    DeepSeekBalanceInfo(
                        currency: "CNY",
                        totalBalance: "110.00",
                        grantedBalance: "10.00",
                        toppedUpBalance: "100.00"
                    )
                ]
            ))
        })

        #expect(store.setStoredAPIKey("sk-fixture") == nil)
        await store.refreshTask?.value
        #expect(store.reading.remainingPercent == nil)
        #expect(store.reading.headline == "¥110.00")
        #expect(store.reading.displayedHeadline == "¥110.00")
        #expect(store.reading.details.contains { $0.label == "赠金" && $0.value == "¥10.00" })
        #expect(store.reading.details.contains { $0.label == "充值" && $0.value == "¥100.00" })
        #expect(store.reading.warningLevel == .normal)
        #expect(store.reading.historyPoints.contains {
            $0.metricKey == "CNY" && $0.remaining == 110 && $0.unit == .currency && $0.isCanonical
        })
        #expect(store.lastError == nil)
        #expect(
            DeepSeekQuotaStore.origin(balance: store.balance, headline: "¥110.00").currentReading
                == "本次取的是 人民币 总可用余额，因此显示 ¥110.00。"
        )
        store.stop()
    }

    @Test("reads the API key from the named environment variable")
    @MainActor
    func refreshReadsEnvironmentVariable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-deepseek-env-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let credentialStore = KimiCredentialStore(
            filePath: directory.appendingPathComponent("c.json").path
        )
        let seenKey = SeenValue<String>()
        let store = DeepSeekQuotaStore(
            credentialStore: credentialStore,
            environment: { ["MY_DS_KEY": "sk-from-env"] },
            fetch: { key in
                seenKey.value = key
                return .success(DeepSeekBalance(
                    isAvailable: true,
                    infos: [
                        DeepSeekBalanceInfo(
                            currency: "USD",
                            totalBalance: "8.00",
                            grantedBalance: "0.00",
                            toppedUpBalance: "8.00"
                        )
                    ]
                ))
            }
        )

        #expect(store.setEnvironmentVariableName("MY_DS_KEY") == nil)
        await store.refreshTask?.value
        #expect(seenKey.value == "sk-from-env")
        #expect(store.reading.headline == "$8.00")
        #expect(store.configuredEnvironmentVariableName == "MY_DS_KEY")
        #expect(!store.hasStoredAPIKey)
        #expect(try credentialStore.loadDeepSeek().get().apiKey == nil)
        store.stop()
    }

    @Test("missing credentials keep the placeholder and surface an error")
    @MainActor
    func missingCredentialsKeepPlaceholder() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-deepseek-missing-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = DeepSeekQuotaStore(
            credentialStore: KimiCredentialStore(
                filePath: directory.appendingPathComponent("c.json").path
            ),
            fetch: { _ in
                Issue.record("must not call DeepSeek without a key")
                return .failure(DeepSeekClientError(.credentials, "unused"))
            }
        )

        store.refresh()
        #expect(store.reading.headline == nil)
        #expect(store.reading.displayedHeadline == "--")
        #expect(store.reading.remainingPercent == nil)
        #expect(store.lastError == "尚未设置环境变量名")
        store.stop()
    }
}

private final class SeenValue<Value>: @unchecked Sendable {
    var value: Value?
}
