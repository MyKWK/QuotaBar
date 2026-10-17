import Foundation

// MARK: - DeepSeek GET /user/balance payload
//
// Official schema: https://api-docs.deepseek.com/zh-cn/api/get-user-balance
// Amounts are decimal strings. Prefer CNY when both CNY and USD are present.

struct DeepSeekBalanceInfo: Equatable, Sendable {
    var currency: String
    var totalBalance: String
    var grantedBalance: String
    var toppedUpBalance: String
}

struct DeepSeekBalance: Equatable, Sendable {
    var isAvailable: Bool
    var infos: [DeepSeekBalanceInfo]

    var primary: DeepSeekBalanceInfo? {
        infos.first { $0.currency.caseInsensitiveCompare("CNY") == .orderedSame }
            ?? infos.first { $0.currency.caseInsensitiveCompare("USD") == .orderedSame }
            ?? infos.first
    }
}

struct DeepSeekClientError: Error, Equatable {
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

enum DeepSeekPayloadParser {
    static func parse(_ data: Data) -> Result<DeepSeekBalance, DeepSeekClientError> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(DeepSeekClientError(.payload, "接口响应不是有效的 JSON"))
        }

        let availableValue = root["is_available"] ?? root["isAvailable"]
        guard let isAvailable = bool(availableValue) else {
            return .failure(DeepSeekClientError(.payload, "接口响应缺少账户可用状态"))
        }

        let rawInfos = root["balance_infos"] ?? root["balanceInfos"]
        guard let items = rawInfos as? [Any], !items.isEmpty else {
            return .failure(DeepSeekClientError(.payload, "接口响应缺少余额明细"))
        }

        var infos: [DeepSeekBalanceInfo] = []
        infos.reserveCapacity(items.count)
        for item in items {
            guard let object = item as? [String: Any],
                  let currency = string(object["currency"]), !currency.isEmpty,
                  let total = string(object["total_balance"] ?? object["totalBalance"]),
                  let granted = string(object["granted_balance"] ?? object["grantedBalance"]),
                  let toppedUp = string(object["topped_up_balance"] ?? object["toppedUpBalance"]) else {
                return .failure(DeepSeekClientError(.payload, "接口响应缺少余额字段"))
            }
            infos.append(DeepSeekBalanceInfo(
                currency: currency,
                totalBalance: total,
                grantedBalance: granted,
                toppedUpBalance: toppedUp
            ))
        }

        return .success(DeepSeekBalance(isAvailable: isAvailable, infos: infos))
    }

    static func numericAmount(_ raw: String) -> Double? {
        Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func formattedAmount(_ raw: String, currency: String) -> String {
        currencySymbol(currency) + raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func currencySymbol(_ currency: String) -> String {
        switch currency.uppercased() {
        case "CNY":
            return "¥"
        case "USD":
            return "$"
        default:
            return "\(currency) "
        }
    }

    static func currencyLabel(_ currency: String) -> String {
        switch currency.uppercased() {
        case "CNY":
            return "人民币"
        case "USD":
            return "美元"
        default:
            return currency
        }
    }

    static func isZeroAmount(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Decimal(string: trimmed) else { return false }
        return value == 0
    }

    static func warningLevel(for balance: DeepSeekBalance) -> QuotaWarningLevel {
        if !balance.isAvailable { return .exhausted }
        if let primary = balance.primary, isZeroAmount(primary.totalBalance) {
            return .exhausted
        }
        return .normal
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            switch value.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return nil
    }
}
