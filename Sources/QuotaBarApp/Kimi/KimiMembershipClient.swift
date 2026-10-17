import Foundation

// MARK: - Kimi membership API
//
// Migrated from the original Kimi baseline (Creative/QuotaBar main.swift).
// Tokens are only ever placed in request headers / bodies and persisted through
// `KimiCredentialStore`; they are never logged or included in error messages.

final class KimiMembershipClient: @unchecked Sendable {
    private let credentialStore: KimiCredentialStore
    private let session: URLSession
    private let membershipURL = URL(string: KimiQuotaConfig.membershipURL)!
    private let refreshURL = URL(string: "https://auth.kimi.com/api/account.gateway.v1.AuthService/RefreshToken")!

    init(credentialStore: KimiCredentialStore, session: URLSession? = nil) {
        self.credentialStore = credentialStore
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

    func fetch(completion: @escaping @Sendable (Result<MembershipStats, KimiClientError>) -> Void) {
        let credentials: KimiCredentials
        switch credentialStore.load() {
        case .success(let value): credentials = value
        case .failure(let error):
            completion(.failure(KimiClientError(.credentials, error.message)))
            return
        }

        let accessNeedsRefresh = credentials.accessToken?.isEmpty ?? true
            || (JWTClaims.expiry(credentials.accessToken)?.timeIntervalSinceNow ?? 3600) < 90
        if accessNeedsRefresh, let refreshToken = credentials.refreshToken, !refreshToken.isEmpty {
            refresh(refreshToken: refreshToken, accessToken: credentials.accessToken) { [weak self] result in
                switch result {
                case .success(let updated): self?.requestStats(credentials: updated, mayRefresh: false, completion: completion)
                case .failure(let error): completion(.failure(error))
                }
            }
        } else if let accessToken = credentials.accessToken, !accessToken.isEmpty {
            requestStats(credentials: credentials, mayRefresh: true, completion: completion)
        } else {
            completion(.failure(KimiClientError(.credentials, "尚未设置 Kimi 网页登录凭据")))
        }
    }

    private func requestStats(
        credentials: KimiCredentials,
        mayRefresh: Bool,
        completion: @escaping @Sendable (Result<MembershipStats, KimiClientError>) -> Void
    ) {
        guard let accessToken = credentials.accessToken, !accessToken.isEmpty else {
            completion(.failure(KimiClientError(.credentials, "缺少 access_token")))
            return
        }
        var request = URLRequest(url: membershipURL)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                completion(.failure(KimiClientError(.network, "网络请求失败：\(error.localizedDescription)")))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(KimiClientError(.network, "未收到有效的 HTTP 响应")))
                return
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                if mayRefresh, let refreshToken = credentials.refreshToken, !refreshToken.isEmpty {
                    self?.refresh(refreshToken: refreshToken, accessToken: credentials.accessToken) { [weak self] result in
                        switch result {
                        case .success(let updated):
                            self?.requestStats(credentials: updated, mayRefresh: false, completion: completion)
                        case .failure(let error): completion(.failure(error))
                        }
                    }
                } else {
                    completion(.failure(KimiClientError(.authentication, "网页登录已过期，请重新设置登录凭据")))
                }
                return
            }
            if http.statusCode == 429 {
                completion(.failure(KimiClientError(.rateLimited, "请求过于频繁，已自动降低刷新频率", retryAfter: Self.retryAfter(http))))
                return
            }
            guard (200..<300).contains(http.statusCode), let data else {
                completion(.failure(KimiClientError(.server, "Kimi 额度接口暂不可用（HTTP \(http.statusCode)）")))
                return
            }
            completion(KimiPayloadParser.parse(data))
        }.resume()
    }

    private func refresh(
        refreshToken: String,
        accessToken: String?,
        completion: @escaping @Sendable (Result<KimiCredentials, KimiClientError>) -> Void
    ) {
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("2.0.0", forHTTPHeaderField: "x-msh-version")
        request.setValue("web", forHTTPHeaderField: "x-msh-platform")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "R-Timezone")
        // The current web client sends device/session identity alongside refresh requests.
        // These values are JWT claims from the same credential pair, not browser storage.
        let claims = JWTClaims.payload(accessToken)
        if let deviceID = claims?["device_id"] as? String {
            request.setValue(deviceID, forHTTPHeaderField: "x-msh-device-id")
        }
        if let sessionID = claims?["ssid"] as? String {
            request.setValue(sessionID, forHTTPHeaderField: "x-msh-session-id")
        }
        if let userID = claims?["sub"] as? String {
            request.setValue(userID, forHTTPHeaderField: "X-Traffic-Id")
        }

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                completion(.failure(KimiClientError(.network, "登录凭据续期失败：\(error.localizedDescription)")))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(KimiClientError(.network, "登录凭据续期未收到有效响应")))
                return
            }
            if http.statusCode == 429 {
                completion(.failure(KimiClientError(.rateLimited, "凭据续期过于频繁，已自动退避", retryAfter: Self.retryAfter(http))))
                return
            }
            guard (200..<300).contains(http.statusCode), let data,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccess = (object["access_token"] ?? object["accessToken"]) as? String,
                  !newAccess.isEmpty else {
                let message = (http.statusCode == 401 || http.statusCode == 403)
                    ? "refresh_token 已失效，请重新登录 Kimi 并设置凭据"
                    : "登录凭据续期失败（HTTP \(http.statusCode)）"
                completion(.failure(KimiClientError(.authentication, message)))
                return
            }
            let rotatedRefresh = ((object["refresh_token"] ?? object["refreshToken"]) as? String) ?? refreshToken
            let updated = KimiCredentials(accessToken: newAccess, refreshToken: rotatedRefresh)
            if let saveError = self?.credentialStore.save(updated) {
                completion(.failure(KimiClientError(.credentials, saveError)))
            } else {
                completion(.success(updated))
            }
        }.resume()
    }

    private static func retryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(value)
    }
}
