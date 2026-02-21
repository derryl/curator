import Foundation

final class TraktAuthManager: Sendable {
    private let session: URLSession

    init() {
        self.session = URLSession.shared
    }

    var isAuthenticated: Bool {
        KeychainHelper.readString(key: .traktAccessToken) != nil
    }

    var accessToken: String? {
        KeychainHelper.readString(key: .traktAccessToken)
    }

    // MARK: - Device Code Flow

    func requestDeviceCode() async throws -> TraktDeviceCode {
        let url = Constants.Trakt.baseURL.appendingPathComponent("/oauth/device/code")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_id": Constants.Trakt.clientId,
        ])

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(TraktDeviceCode.self, from: data)
    }

    func pollForToken(deviceCode: String) async throws -> TraktToken {
        let url = Constants.Trakt.baseURL.appendingPathComponent("/oauth/device/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "code": deviceCode,
            "client_id": Constants.Trakt.clientId,
            "client_secret": Constants.Trakt.clientSecret,
        ])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktAuthError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let token = try JSONDecoder().decode(TraktToken.self, from: data)
            saveTokens(token)
            return token
        case 400:
            throw TraktAuthError.pendingAuthorization
        case 404:
            throw TraktAuthError.invalidDeviceCode
        case 409:
            throw TraktAuthError.alreadyUsed
        case 410:
            throw TraktAuthError.expired
        case 418:
            throw TraktAuthError.denied
        case 429:
            throw TraktAuthError.slowDown
        default:
            throw TraktAuthError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    func refreshToken() async throws -> TraktToken {
        guard let refreshToken = KeychainHelper.readString(key: .traktRefreshToken) else {
            throw TraktAuthError.noRefreshToken
        }

        let url = Constants.Trakt.baseURL.appendingPathComponent("/oauth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "refresh_token": refreshToken,
            "client_id": Constants.Trakt.clientId,
            "client_secret": Constants.Trakt.clientSecret,
            "grant_type": "refresh_token",
            "redirect_uri": Constants.Trakt.redirectURI,
        ])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TraktAuthError.refreshFailed
        }

        let token = try JSONDecoder().decode(TraktToken.self, from: data)
        saveTokens(token)
        return token
    }

    func clearTokens() {
        KeychainHelper.delete(key: .traktAccessToken)
        KeychainHelper.delete(key: .traktRefreshToken)
    }

    // MARK: - Private

    private func saveTokens(_ token: TraktToken) {
        try? KeychainHelper.save(token.accessToken, for: .traktAccessToken)
        try? KeychainHelper.save(token.refreshToken, for: .traktRefreshToken)
    }
}

enum TraktAuthError: LocalizedError {
    case pendingAuthorization
    case invalidDeviceCode
    case alreadyUsed
    case expired
    case denied
    case slowDown
    case invalidResponse
    case httpError(statusCode: Int)
    case noRefreshToken
    case refreshFailed

    var errorDescription: String? {
        switch self {
        case .pendingAuthorization: "Waiting for user authorization"
        case .invalidDeviceCode: "Invalid device code"
        case .alreadyUsed: "Device code already used"
        case .expired: "Device code expired"
        case .denied: "User denied authorization"
        case .slowDown: "Polling too fast"
        case .invalidResponse: "Invalid response from Trakt"
        case .httpError(let code): "Trakt returned error \(code)"
        case .noRefreshToken: "No refresh token available"
        case .refreshFailed: "Token refresh failed"
        }
    }
}
