import Foundation

actor TraktClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let authManager: TraktAuthManager

    init(authManager: TraktAuthManager) {
        self.session = URLSession.shared
        self.decoder = JSONDecoder()
        self.authManager = authManager
    }

    // MARK: - Trending

    func trendingMovies(page: Int = 1, limit: Int = 20) async throws -> [TraktTrendingMovie] {
        try await get("/movies/trending", query: [
            "page": String(page),
            "limit": String(limit),
        ])
    }

    func trendingShows(page: Int = 1, limit: Int = 20) async throws -> [TraktTrendingShow] {
        try await get("/shows/trending", query: [
            "page": String(page),
            "limit": String(limit),
        ])
    }

    // MARK: - Popular

    func popularMovies(page: Int = 1, limit: Int = 20) async throws -> [TraktMovie] {
        try await get("/movies/popular", query: [
            "page": String(page),
            "limit": String(limit),
        ])
    }

    func popularShows(page: Int = 1, limit: Int = 20) async throws -> [TraktShow] {
        try await get("/shows/popular", query: [
            "page": String(page),
            "limit": String(limit),
        ])
    }

    // MARK: - Recommendations (authenticated)

    func recommendedMovies(limit: Int = 20, ignoreWatched: Bool = false, ignoreCollected: Bool = false) async throws -> [TraktMovie] {
        var query = ["limit": String(limit)]
        if ignoreWatched { query["ignore_watched"] = "true" }
        if ignoreCollected { query["ignore_collected"] = "true" }
        return try await get("/recommendations/movies", query: query, authenticated: true)
    }

    func recommendedShows(limit: Int = 20, ignoreWatched: Bool = false, ignoreCollected: Bool = false) async throws -> [TraktShow] {
        var query = ["limit": String(limit)]
        if ignoreWatched { query["ignore_watched"] = "true" }
        if ignoreCollected { query["ignore_collected"] = "true" }
        return try await get("/recommendations/shows", query: query, authenticated: true)
    }

    // MARK: - User Lists (public, no auth needed)

    func userListItems(username: String, listSlug: String, type: String, limit: Int = 20) async throws -> [TraktListItem] {
        try await get("/users/\(username)/lists/\(listSlug)/items/\(type)", query: [
            "limit": String(limit),
        ], authenticated: false)
    }

    // MARK: - Watch History (authenticated)

    func watchHistory(type: String = "movies", page: Int = 1, limit: Int = 5) async throws -> [TraktHistoryItem] {
        try await get("/sync/history/\(type)", query: [
            "page": String(page),
            "limit": String(limit),
        ], authenticated: true)
    }

    // MARK: - Genres

    func movieGenres() async throws -> [TraktGenre] {
        try await get("/genres/movies")
    }

    func showGenres() async throws -> [TraktGenre] {
        try await get("/genres/shows")
    }

    // MARK: - Private

    private func get<T: Decodable>(
        _ path: String,
        query: [String: String] = [:],
        authenticated: Bool = false
    ) async throws -> T {
        var components = URLComponents(url: Constants.Trakt.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.Trakt.apiVersion, forHTTPHeaderField: "trakt-api-version")
        request.setValue(Constants.Trakt.clientId, forHTTPHeaderField: "trakt-api-key")

        if authenticated, let token = authManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktClientError.invalidResponse
        }

        // Handle token refresh on 401
        if httpResponse.statusCode == 401 && authenticated {
            _ = try await authManager.refreshToken()
            // Retry with new token
            if let newToken = authManager.accessToken {
                request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            }
            let (retryData, retryResponse) = try await session.data(for: request)
            guard let retryHttp = retryResponse as? HTTPURLResponse,
                  (200...299).contains(retryHttp.statusCode) else {
                throw TraktClientError.httpError(statusCode: (retryResponse as? HTTPURLResponse)?.statusCode ?? 0)
            }
            return try decoder.decode(T.self, from: retryData)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TraktClientError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}

enum TraktClientError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from Trakt"
        case .httpError(let code): "Trakt returned error \(code)"
        }
    }
}
