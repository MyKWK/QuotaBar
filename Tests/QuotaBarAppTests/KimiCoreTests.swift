import Foundation
import Testing
@testable import QuotaBarApp

@Suite("Kimi core (migrated baseline)")
struct KimiCoreTests {
    // MARK: Payload parsing (fixtures ported from the baseline self-test)

    @Test("parses snake_case membership payload")
    func parsesSnakeCasePayload() throws {
        let data = Data(#"{"subscription_balance":{"amount_used_ratio":0.7845,"kimi_code_used_ratio":0.12,"expire_time":"2026-09-09"},"gift_balances":[]}"#.utf8)
        let result = KimiPayloadParser.parse(data)
        let stats = try #require(try? result.get())
        #expect(abs(stats.remainingPercent - 21.55) < 0.001)
        #expect(abs(stats.usedPercent - 78.45) < 0.001)
        #expect(stats.codeUsedPercent.map { abs($0 - 12) < 0.001 } == true)
        #expect(stats.resetTime == "2026-09-09")
        #expect(stats.giftsCount == 0)
    }

    @Test("parses camelCase membership payload")
    func parsesCamelCasePayload() throws {
        let data = Data(#"{"subscriptionBalance":{"amountUsedRatio":0.25,"kimiCodeUsedRatio":0.1},"giftBalances":[{}]}"#.utf8)
        let stats = try #require(try? KimiPayloadParser.parse(data).get())
        #expect(abs(stats.remainingPercent - 75) < 0.001)
        #expect(stats.giftsCount == 1)
    }

    @Test("treats ratios above one as already-percent and clamps to 0...100")
    func clampsPercentRange() throws {
        let data = Data(#"{"subscription_balance":{"amount_used_ratio":140},"gift_balances":[]}"#.utf8)
        let stats = try #require(try? KimiPayloadParser.parse(data).get())
        #expect(stats.usedPercent == 100)
        #expect(stats.remainingPercent == 0)
    }

    @Test("accepts numeric strings for the used ratio")
    func acceptsNumericStrings() throws {
        let data = Data(#"{"subscription_balance":{"amount_used_ratio":"0.5"},"gift_balances":[]}"#.utf8)
        let stats = try #require(try? KimiPayloadParser.parse(data).get())
        #expect(abs(stats.remainingPercent - 50) < 0.001)
    }

    @Test("fails with payload kind when the balance field is missing")
    func failsOnMissingBalance() {
        let data = Data(#"{"unexpected":true}"#.utf8)
        switch KimiPayloadParser.parse(data) {
        case .success:
            Issue.record("expected parsing to fail")
        case .failure(let error):
            #expect(error.kind == .payload)
            #expect(!error.message.isEmpty)
        }
    }

    // MARK: JWT claims

    @Test("reads expiry and app_id from a JWT payload")
    func readsJWTClaims() throws {
        let token = Self.makeJWT(payload: #"{"exp":1893456000,"app_id":"kimi"}"#)
        let expiry = try #require(JWTClaims.expiry(token))
        #expect(expiry.timeIntervalSince1970 == 1_893_456_000)
        #expect(JWTClaims.appID(token) == "kimi")
    }

    @Test("rejects malformed tokens")
    func rejectsMalformedTokens() {
        #expect(JWTClaims.payload(nil) == nil)
        #expect(JWTClaims.payload("not-a-jwt") == nil)
        #expect(JWTClaims.expiry("a.b") == nil)
    }

    // MARK: Credential store (isolated persistent JSON + migration backup)

    @Test("saves, loads, merges and deletes credentials in app-owned JSON")
    func credentialStoreRoundtrip() throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentPath = directory.appendingPathComponent("credentials.json").path
        let store = KimiCredentialStore(filePath: documentPath)

        #expect(try store.load().get().isEmpty)

        let saveError = store.save(KimiCredentials(accessToken: "fixture-access", refreshToken: "fixture-refresh"))
        #expect(saveError == nil)

        let loaded = try store.load().get()
        #expect(loaded.accessToken == "fixture-access")
        #expect(loaded.refreshToken == "fixture-refresh")

        #expect(FileManager.default.fileExists(atPath: documentPath))
        let attributes = try FileManager.default.attributesOfItem(atPath: documentPath)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)

        #expect(store.merge(refreshToken: "fixture-rotated") == nil)
        let merged = try store.load().get()
        #expect(merged.accessToken == "fixture-access")
        #expect(merged.refreshToken == "fixture-rotated")

        #expect(store.delete() == nil)
        #expect(!FileManager.default.fileExists(atPath: documentPath))

        #expect(store.save(KimiCredentials()) == "凭据不能为空")
    }

    @Test("preserves Kimi credentials when saving and deleting DeepSeek")
    func preservesKimiWhenSavingDeepSeek() throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KimiCredentialStore(
            filePath: directory.appendingPathComponent("credentials.json").path
        )

        #expect(store.save(KimiCredentials(accessToken: "fixture-access", refreshToken: "fixture-refresh")) == nil)
        #expect(store.saveDeepSeek(DeepSeekCredentials(source: .storedKey, apiKey: "sk-fixture")) == nil)

        let kimi = try store.load().get()
        let deepseek = try store.loadDeepSeek().get()
        #expect(kimi.accessToken == "fixture-access")
        #expect(deepseek.source == .storedKey)
        #expect(deepseek.apiKey == "sk-fixture")
        #expect(deepseek.environmentVariableName == nil)

        #expect(store.saveDeepSeek(DeepSeekCredentials(
            source: .environmentVariable,
            environmentVariableName: "DEEPSEEK_API_KEY",
            apiKey: "sk-should-not-persist"
        )) == nil)
        let envOnly = try store.loadDeepSeek().get()
        #expect(envOnly.source == .environmentVariable)
        #expect(envOnly.environmentVariableName == "DEEPSEEK_API_KEY")
        #expect(envOnly.apiKey == nil)
        #expect(try store.load().get().accessToken == "fixture-access")

        let fileText = try String(
            contentsOfFile: directory.appendingPathComponent("credentials.json").path,
            encoding: .utf8
        )
        #expect(!fileText.contains("sk-should-not-persist"))

        #expect(store.deleteDeepSeek() == nil)
        #expect(try store.loadDeepSeek().get().isEmpty)
        #expect(try store.load().get().accessToken == "fixture-access")
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("credentials.json").path))
    }

    @Test("migrates an old credential file into persistent app JSON")
    func migratesLegacyCredentialFile() throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let documentPath = directory.appendingPathComponent("credentials.json").path
        let legacyPath = directory.appendingPathComponent("legacy.json").path
        let legacy = KimiCredentials(accessToken: "fixture-access", refreshToken: "fixture-refresh")
        try JSONEncoder().encode(legacy).write(to: URL(fileURLWithPath: legacyPath))

        let store = KimiCredentialStore(filePath: documentPath, legacyFilePath: legacyPath)
        #expect(try store.load().get() == legacy)
        #expect(FileManager.default.fileExists(atPath: documentPath))
        #expect(FileManager.default.fileExists(atPath: legacyPath))
    }

    // MARK: Config loading and one-time credential migration

    @Test("writes a default config when the file is missing")
    func writesDefaultConfig() throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("config.json").path

        let config = KimiQuotaConfig.load(from: path)
        #expect(config.label == "Kimi")
        #expect(config.refreshInterval == 60)
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("migrates a plaintext Authorization header into the credential store")
    func migratesAuthorizationHeader() throws {
        let directory = try Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configPath = directory.appendingPathComponent("config.json").path
        let store = KimiCredentialStore(
            filePath: directory.appendingPathComponent("credentials.json").path
        )

        let original: [String: Any] = [
            "label": "Kimi",
            "refreshSeconds": 45,
            "url": KimiQuotaConfig.membershipURL,
            "headers": ["Authorization": "Bearer fixture-migration-token"]
        ]
        let data = try JSONSerialization.data(withJSONObject: original)
        try data.write(to: URL(fileURLWithPath: configPath))

        let config = KimiQuotaConfig.load(from: configPath, migratingTo: store)
        #expect(config.refreshInterval == 45)

        let credentials = try store.load().get()
        #expect(credentials.accessToken == "fixture-migration-token")

        // The rewritten config must no longer contain the token or request overrides.
        let rewrittenText = try String(contentsOfFile: configPath, encoding: .utf8)
        #expect(!rewrittenText.contains("fixture-migration-token"))
        #expect(!rewrittenText.contains("Authorization"))
        #expect(!rewrittenText.contains("\"url\""))
    }

    @Test("normalized bearer token strips the scheme and whitespace")
    func normalizesBearerToken() {
        #expect(KimiQuotaConfig.normalizedBearerToken("  Bearer abc123  ") == "abc123")
        #expect(KimiQuotaConfig.normalizedBearerToken("bearer xyz") == "xyz")
        #expect(KimiQuotaConfig.normalizedBearerToken("plain") == "plain")
        #expect(KimiQuotaConfig.normalizedBearerToken("   ") == nil)
        #expect(KimiQuotaConfig.normalizedBearerToken(nil) == nil)
    }

    // MARK: Helpers

    private static func makeJWT(payload: String) -> String {
        func base64URL(_ string: String) -> String {
            Data(string.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return [base64URL(#"{"alg":"none"}"#), base64URL(payload), "sig"].joined(separator: ".")
    }

    private static func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quotabar-kimi-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
