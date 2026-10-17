import Foundation

// MARK: - Kimi membership payload parsing
//
// Migrated from the original Kimi baseline (Creative/QuotaBar main.swift).

struct MembershipStats: Equatable {
    let usedPercent: Double
    let codeUsedPercent: Double?
    let resetTime: String?
    let giftsCount: Int

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }
}

struct KimiClientError: Error, Equatable {
    enum Kind: Equatable { case credentials, authentication, rateLimited, server, network, payload }
    let kind: Kind
    let message: String
    let retryAfter: TimeInterval?

    init(_ kind: Kind, _ message: String, retryAfter: TimeInterval? = nil) {
        self.kind = kind
        self.message = message
        self.retryAfter = retryAfter
    }
}

enum KimiPayloadParser {
    static func parse(_ data: Data) -> Result<MembershipStats, KimiClientError> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let balance = dictionary(root["subscription_balance"] ?? root["subscriptionBalance"]),
              let usedRatio = ratio(balance["amount_used_ratio"] ?? balance["amountUsedRatio"]) else {
            return .failure(KimiClientError(.payload, "接口响应缺少会员月度额度字段"))
        }

        let codeRatio = ratio(balance["kimi_code_used_ratio"] ?? balance["kimiCodeUsedRatio"])
        let resetTime = string(balance["expire_time"] ?? balance["expireTime"])
        let gifts = (root["gift_balances"] ?? root["giftBalances"]) as? [Any] ?? []
        return .success(MembershipStats(
            usedPercent: percent(usedRatio),
            codeUsedPercent: codeRatio.map(percent),
            resetTime: resetTime,
            giftsCount: gifts.count
        ))
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func ratio(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func percent(_ value: Double) -> Double {
        let converted = value <= 1.000001 ? value * 100 : value
        return max(0, min(100, converted))
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }
}

enum JWTClaims {
    static func payload(_ token: String?) -> [String: Any]? {
        guard let token, token.split(separator: ".").count == 3 else { return nil }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    static func expiry(_ token: String?) -> Date? {
        guard let value = payload(token)?["exp"] as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: value.doubleValue)
    }

    static func appID(_ token: String?) -> String? {
        payload(token)?["app_id"] as? String
    }
}
