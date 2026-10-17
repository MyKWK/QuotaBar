import Foundation

// MARK: - DeepSeek official balance API
//
// GET https://api.deepseek.com/user/balance
// Authorization: Bearer <API Key>
// The key is only placed in the request header and is never logged.

final class DeepSeekBalanceClient: Sendable {
    static let balanceURL = URL(string: "https://api.deepseek.com/user/balance")!

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 15
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetch(apiKey: String) async -> Result<DeepSeekBalance, DeepSeekClientError> {
        var request = URLRequest(url: Self.balanceURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(DeepSeekClientError(.network, "未收到有效的 HTTP 响应"))
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                return .failure(DeepSeekClientError(.authentication, "API Key 无效或已过期，请重新配置"))
            }
            if http.statusCode == 429 {
                return .failure(DeepSeekClientError(
                    .rateLimited,
                    "请求过于频繁，已自动降低刷新频率",
                    retryAfter: Self.retryAfter(http)
                ))
            }
            guard (200..<300).contains(http.statusCode) else {
                return .failure(DeepSeekClientError(.server, "DeepSeek 余额接口暂不可用（HTTP \(http.statusCode)）"))
            }
            return DeepSeekPayloadParser.parse(data)
        } catch is CancellationError {
            return .failure(DeepSeekClientError(.network, "余额查询已取消"))
        } catch {
            return .failure(DeepSeekClientError(.network, "网络请求失败：\(error.localizedDescription)"))
        }
    }

    private static func retryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(value)
    }
}
