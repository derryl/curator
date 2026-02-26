import Foundation

actor OverseerrClient {
    private var baseURL: URL
    private var apiKey: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.decoder = JSONDecoder()
    }

    func updateConfiguration(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    // MARK: - Connection Test

    func testConnection() async throws -> Bool {
        let _: OverseerrAboutResponse = try await get("/settings/about")
        return true
    }

    // MARK: - Search

    func search(query: String, page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/search", query: [
            "query": query,
            "page": String(page),
        ])
    }

    // MARK: - Discover

    func discoverTrending(page: Int = 1, language: String? = nil) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        var params = ["page": String(page)]
        if let language { params["language"] = language }
        return try await get("/discover/trending", query: params)
    }

    func discoverMovies(page: Int = 1, language: String? = nil) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        var params = ["page": String(page)]
        if let language { params["language"] = language }
        return try await get("/discover/movies", query: params)
    }

    func discoverTv(page: Int = 1, language: String? = nil) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        var params = ["page": String(page)]
        if let language { params["language"] = language }
        return try await get("/discover/tv", query: params)
    }

    func discoverUpcomingMovies(page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/discover/movies/upcoming", query: ["page": String(page)])
    }

    func discoverUpcomingTv(page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/discover/tv/upcoming", query: ["page": String(page)])
    }

    func discoverMoviesByGenre(genreId: Int, page: Int = 1, language: String? = nil) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        var params = ["page": String(page)]
        if let language { params["language"] = language }
        return try await get("/discover/movies/genre/\(genreId)", query: params)
    }

    func discoverTvByGenre(genreId: Int, page: Int = 1, language: String? = nil) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        var params = ["page": String(page)]
        if let language { params["language"] = language }
        return try await get("/discover/tv/genre/\(genreId)", query: params)
    }

    func discoverMoviesByKeyword(keywordId: Int, page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/discover/movies", query: [
            "page": String(page),
            "withKeywords": String(keywordId),
        ])
    }

    func discoverTvByKeyword(keywordId: Int, page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/discover/tv", query: [
            "page": String(page),
            "withKeywords": String(keywordId),
        ])
    }

    func movieGenreSlider() async throws -> [OverseerrGenreSliderItem] {
        try await get("/discover/genreslider/movie")
    }

    func tvGenreSlider() async throws -> [OverseerrGenreSliderItem] {
        try await get("/discover/genreslider/tv")
    }

    // MARK: - Details

    func movieDetails(tmdbId: Int) async throws -> OverseerrMovieDetails {
        try await get("/movie/\(tmdbId)")
    }

    func tvDetails(tmdbId: Int) async throws -> OverseerrTvDetails {
        try await get("/tv/\(tmdbId)")
    }

    func movieSimilar(tmdbId: Int, page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/movie/\(tmdbId)/similar", query: ["page": String(page)])
    }

    func movieRecommendations(tmdbId: Int, page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/movie/\(tmdbId)/recommendations", query: ["page": String(page)])
    }

    func tvSimilar(tmdbId: Int, page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/tv/\(tmdbId)/similar", query: ["page": String(page)])
    }

    func tvRecommendations(tmdbId: Int, page: Int = 1) async throws -> OverseerrPagedResponse<OverseerrMediaResult> {
        try await get("/tv/\(tmdbId)/recommendations", query: ["page": String(page)])
    }

    // MARK: - Person

    func personDetails(personId: Int) async throws -> OverseerrPersonDetails {
        try await get("/person/\(personId)")
    }

    func personCombinedCredits(personId: Int) async throws -> OverseerrPersonCombinedCredits {
        try await get("/person/\(personId)/combined_credits")
    }

    // MARK: - Service Configuration (Quality Profiles)

    func radarrServices() async throws -> [OverseerrServiceInfo] {
        try await get("/service/radarr")
    }

    func radarrServiceDetails(serverId: Int) async throws -> OverseerrServiceDetails {
        try await get("/service/radarr/\(serverId)")
    }

    func sonarrServices() async throws -> [OverseerrServiceInfo] {
        try await get("/service/sonarr")
    }

    func sonarrServiceDetails(serverId: Int) async throws -> OverseerrServiceDetails {
        try await get("/service/sonarr/\(serverId)")
    }

    // MARK: - Requests

    func createRequest(
        mediaType: String,
        mediaId: Int,
        serverId: Int? = nil,
        profileId: Int? = nil,
        rootFolder: String? = nil
    ) async throws -> OverseerrMediaRequest {
        var body: [String: Any] = [
            "mediaType": mediaType,
            "mediaId": mediaId,
        ]
        if let serverId { body["serverId"] = serverId }
        if let profileId { body["profileId"] = profileId }
        if let rootFolder { body["rootFolder"] = rootFolder }
        return try await post("/request", body: body)
    }

    // MARK: - Auth

    func authenticate(email: String, password: String) async throws -> OverseerrUser {
        let body: [String: Any] = [
            "email": email,
            "password": password,
        ]
        return try await post("/auth/local", body: body)
    }

    // MARK: - Private Helpers

    private func apiURL(_ path: String, query: [String: String] = [:]) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(Constants.Overseerr.apiPathPrefix + path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var request = URLRequest(url: apiURL(path, query: query))
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: apiURL(path))
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OverseerrError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            var serverMessage: String?
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                serverMessage = message
            }
            throw OverseerrError.httpError(statusCode: httpResponse.statusCode, message: serverMessage)
        }
    }
}

// MARK: - Error Type

enum OverseerrError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from server"
        case .httpError(let statusCode, let message):
            if let message {
                "Error \(statusCode): \(message)"
            } else {
                "Server returned error \(statusCode)"
            }
        case .notConfigured:
            "Overseerr is not configured"
        }
    }
}

// MARK: - Internal Response Types

private struct OverseerrAboutResponse: Decodable {
    let version: String?
}
