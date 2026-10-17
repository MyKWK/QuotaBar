import Foundation

// MARK: - Configuration
//
// Migrated from the original Kimi baseline (Creative/QuotaBar main.swift).
// Reads ~/.quotabar.json; performs the one-time migration that moves a plaintext
// Authorization header out of the config file into the credentials store. The
// migrated token is never logged.

struct KimiQuotaConfig {
    static let membershipURL =
        "https://www.kimi.com/apiv2/kimi.gateway.membership.v2.MembershipService/GetSubscriptionStats"

    var label = "Kimi"
    var refreshMinutes: Double = 1
    var refreshSeconds: Double?

    var isKimiMembership: Bool {
        true
    }

    // Membership data changes only after usage. A 30-second floor keeps refreshes useful
    // without hammering a private, undocumented endpoint.
    var refreshInterval: TimeInterval {
        if let refreshSeconds { return max(30, refreshSeconds) }
        return max(0.5, refreshMinutes) * 60
    }

    static var defaultConfigPath: String {
        NSHomeDirectory() + "/.quotabar.json"
    }

    static func load(
        from path: String = defaultConfigPath,
        migratingTo credentialStore: KimiCredentialStore? = nil
    ) -> KimiQuotaConfig {
        var config = KimiQuotaConfig()
        guard let data = FileManager.default.contents(atPath: path),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let defaultObject: [String: Any] = [
                "label": "Kimi",
                "source": "kimiMembership",
                "refreshSeconds": 60
            ]
            writeConfig(defaultObject, to: path)
            return config
        }

        // One-time migration from the prototype, which allowed an Authorization header
        // in plaintext. Only remove it after it is safely stored in the credentials file.
        if let credentialStore,
           var headers = object["headers"] as? [String: String],
           let authorizationKey = headers.keys.first(where: { $0.caseInsensitiveCompare("Authorization") == .orderedSame }),
           let token = normalizedBearerToken(headers[authorizationKey]),
           credentialStore.merge(accessToken: token) == nil {
            headers.removeValue(forKey: authorizationKey)
            if headers.isEmpty {
                object.removeValue(forKey: "headers")
            } else {
                object["headers"] = headers
            }
            object["source"] = "kimiMembership"
            object.removeValue(forKey: "url")
            object.removeValue(forKey: "method")
            object.removeValue(forKey: "body")
            object.removeValue(forKey: "jsonPath")
            object.removeValue(forKey: "multiply")
            writeConfig(object, to: path)
        }

        if let value = object["label"] as? String { config.label = value }
        if let value = number(object["refreshMinutes"]) { config.refreshMinutes = max(0.5, value) }
        if let value = number(object["refreshSeconds"]) { config.refreshSeconds = max(30, value) }
        return config
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    static func normalizedBearerToken(_ value: String?) -> String? {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.lowercased().hasPrefix("bearer ") {
            value = String(value.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value.isEmpty ? nil : value
    }

    private static func writeConfig(_ object: [String: Any], to path: String) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }
        let url = URL(fileURLWithPath: path)
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        } catch {
            // The settings page surfaces configuration problems without ever logging credentials.
        }
    }
}
