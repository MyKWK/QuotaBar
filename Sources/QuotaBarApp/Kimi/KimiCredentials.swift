import Foundation

// Persistent app-owned credentials. They live outside the app bundle at
// ~/Library/Application Support/QuotaBar/credentials.json (0600), so replacing
// a DMG never removes them. The document is ignored by Git and never uses an
// environment variable.

struct KimiCredentials: Codable, Equatable {
    var accessToken: String?
    var refreshToken: String?

    var isEmpty: Bool {
        (accessToken?.isEmpty ?? true) && (refreshToken?.isEmpty ?? true)
    }
}

/// Independent slots are reserved for future GPT/ZCode web credentials. GPT's
/// present integration is read-only and therefore does not populate its slot.
/// DeepSeek stores either an environment-variable name or the API key itself.
struct ServiceCredentialsDocument: Codable, Equatable {
    var version: Int = 1
    var kimi: KimiCredentials?
    var gpt: KimiCredentials?
    var zcode: KimiCredentials?
    var deepseek: DeepSeekCredentials?

    var isEmpty: Bool {
        (kimi?.isEmpty ?? true)
            && (gpt?.isEmpty ?? true)
            && (zcode?.isEmpty ?? true)
            && (deepseek?.isEmpty ?? true)
    }
}

struct KimiCredentialStoreError: Error, Equatable { let message: String }

final class KimiCredentialStore {
    static var defaultFilePath: String { AppPaths.credentialsFile.path }
    static var defaultLegacyFilePath: String { NSHomeDirectory() + "/.quotabar-credentials.json" }

    let filePath: String
    let legacyFilePath: String
    private var cached: KimiCredentials?
    private var cachedDeepSeek: DeepSeekCredentials?

    init(
        filePath: String = KimiCredentialStore.defaultFilePath,
        legacyFilePath: String = KimiCredentialStore.defaultLegacyFilePath
    ) {
        self.filePath = filePath
        self.legacyFilePath = legacyFilePath
    }

    func load() -> Result<KimiCredentials, KimiCredentialStoreError> {
        if let cached { return .success(cached) }
        switch loadDocument() {
        case .failure(let error): return .failure(error)
        case .success(let document):
            if let credentials = document.kimi, !credentials.isEmpty {
                cached = credentials
                return .success(credentials)
            }
        }
        if let migrated = migrateLegacyFile() { return migrated }
        return .success(KimiCredentials())
    }

    @discardableResult
    func save(_ credentials: KimiCredentials) -> String? {
        guard !credentials.isEmpty else { return "凭据不能为空" }
        switch loadDocument() {
        case .failure(let error): return error.message
        case .success(var document):
            document.kimi = credentials
            guard writeDocument(document) else { return "凭据保存失败" }
        }
        cached = credentials
        return nil
    }

    @discardableResult
    func merge(accessToken: String? = nil, refreshToken: String? = nil) -> String? {
        let current: KimiCredentials
        switch load() {
        case .success(let value): current = value
        case .failure(let error): return error.message
        }
        return save(KimiCredentials(
            accessToken: accessToken ?? current.accessToken,
            refreshToken: refreshToken ?? current.refreshToken
        ))
    }

    @discardableResult
    func delete() -> String? {
        switch loadDocument() {
        case .failure(let error): return error.message
        case .success(var document):
            document.kimi = nil
            if document.isEmpty {
                try? FileManager.default.removeItem(atPath: filePath)
            } else if !writeDocument(document) {
                return "凭据删除失败"
            }
        }
        cached = nil
        return nil
    }

    func loadDeepSeek() -> Result<DeepSeekCredentials, KimiCredentialStoreError> {
        if let cachedDeepSeek { return .success(cachedDeepSeek) }
        switch loadDocument() {
        case .failure(let error): return .failure(error)
        case .success(let document):
            if let credentials = document.deepseek, !credentials.isEmpty {
                cachedDeepSeek = credentials
                return .success(credentials)
            }
        }
        return .success(DeepSeekCredentials())
    }

    @discardableResult
    func saveDeepSeek(_ credentials: DeepSeekCredentials) -> String? {
        let stored = credentials.sanitizedForPersistence()
        guard !stored.isEmpty else { return "凭据不能为空" }
        switch loadDocument() {
        case .failure(let error): return error.message
        case .success(var document):
            document.deepseek = stored
            guard writeDocument(document) else { return "凭据保存失败" }
        }
        cachedDeepSeek = stored
        return nil
    }

    @discardableResult
    func deleteDeepSeek() -> String? {
        switch loadDocument() {
        case .failure(let error): return error.message
        case .success(var document):
            document.deepseek = nil
            if document.isEmpty {
                try? FileManager.default.removeItem(atPath: filePath)
            } else if !writeDocument(document) {
                return "凭据删除失败"
            }
        }
        cachedDeepSeek = nil
        return nil
    }

    private func loadDocument() -> Result<ServiceCredentialsDocument, KimiCredentialStoreError> {
        guard FileManager.default.fileExists(atPath: filePath) else { return .success(ServiceCredentialsDocument()) }
        guard let data = FileManager.default.contents(atPath: filePath),
              let document = try? JSONDecoder().decode(ServiceCredentialsDocument.self, from: data) else {
            return .failure(KimiCredentialStoreError(message: "QuotaBar 凭据文件格式无效"))
        }
        return .success(document)
    }

    private func writeDocument(_ document: ServiceCredentialsDocument) -> Bool {
        do {
            let url = URL(fileURLWithPath: filePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.deletingLastPathComponent().path)
            try JSONEncoder().encode(document).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath)
            return true
        } catch { return false }
    }

    private func migrateLegacyFile() -> Result<KimiCredentials, KimiCredentialStoreError>? {
        guard let data = FileManager.default.contents(atPath: legacyFilePath),
              let credentials = try? JSONDecoder().decode(KimiCredentials.self, from: data),
              !credentials.isEmpty else { return nil }
        guard save(credentials) == nil else {
            return .failure(KimiCredentialStoreError(message: "无法迁移旧版 Kimi 凭据"))
        }
        return .success(credentials)
    }
}
