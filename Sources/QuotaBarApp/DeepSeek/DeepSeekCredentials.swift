import Foundation

// MARK: - DeepSeek API key configuration
//
// Two mutually exclusive sources: an environment-variable *name* (the key
// itself is never written to disk) or the key stored in the shared
// `credentials.json` slot. Resolvers never log the secret.

enum DeepSeekKeySource: String, Codable, CaseIterable, Identifiable, Sendable {
    case environmentVariable
    case storedKey

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .environmentVariable:
            return "环境变量"
        case .storedKey:
            return "直接粘贴 Key"
        }
    }
}

struct DeepSeekCredentials: Codable, Equatable, Sendable {
    var source: DeepSeekKeySource
    var environmentVariableName: String?
    var apiKey: String?

    init(
        source: DeepSeekKeySource = .environmentVariable,
        environmentVariableName: String? = nil,
        apiKey: String? = nil
    ) {
        self.source = source
        self.environmentVariableName = environmentVariableName
        self.apiKey = apiKey
    }

    var isEmpty: Bool {
        switch source {
        case .environmentVariable:
            return DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName(environmentVariableName) == nil
        case .storedKey:
            return DeepSeekAPIKeyResolver.normalizedAPIKey(apiKey) == nil
        }
    }

    func sanitizedForPersistence() -> DeepSeekCredentials {
        switch source {
        case .environmentVariable:
            return DeepSeekCredentials(
                source: .environmentVariable,
                environmentVariableName: DeepSeekAPIKeyResolver.normalizedEnvironmentVariableName(
                    environmentVariableName
                )
            )
        case .storedKey:
            return DeepSeekCredentials(
                source: .storedKey,
                apiKey: DeepSeekAPIKeyResolver.normalizedAPIKey(apiKey)
            )
        }
    }
}

enum DeepSeekAPIKeyResolver {
    static func normalizedEnvironmentVariableName(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("$") {
            value = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !value.isEmpty else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let start = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        guard let first = value.unicodeScalars.first, start.contains(first),
              value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return value
    }

    static func normalizedAPIKey(_ raw: String?) -> String? {
        KimiQuotaConfig.normalizedBearerToken(raw)
    }

    static func resolve(
        _ credentials: DeepSeekCredentials,
        environment: [String: String]
    ) -> Result<String, DeepSeekClientError> {
        let stored = credentials.sanitizedForPersistence()
        switch stored.source {
        case .environmentVariable:
            guard let name = stored.environmentVariableName else {
                return .failure(DeepSeekClientError(.credentials, "尚未设置环境变量名"))
            }
            guard let value = normalizedAPIKey(environment[name]) else {
                return .failure(DeepSeekClientError(
                    .credentials,
                    "环境变量 \(name) 未设置或为空。从「应用程序」启动时通常读不到终端里的变量，可改用直接粘贴 Key。"
                ))
            }
            return .success(value)
        case .storedKey:
            guard let key = stored.apiKey else {
                return .failure(DeepSeekClientError(.credentials, "尚未保存 API Key"))
            }
            return .success(key)
        }
    }
}
