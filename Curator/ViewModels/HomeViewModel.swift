import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    var trendingMovies: [MediaItem] = []
    var trendingShows: [MediaItem] = []
    var popularMovies: [MediaItem] = []
    var popularShows: [MediaItem] = []
    var upcomingMovies: [MediaItem] = []
    var upcomingShows: [MediaItem] = []
    var recommendationShelves: [RecommendationShelf] = []
    var isLoading = false
    var errorMessage: String?

    struct RecommendationShelf: Identifiable {
        let id: String
        let title: String
        let items: [MediaItem]
    }

    func loadContent(
        overseerrClient: OverseerrClient?,
        traktAuthManager: TraktAuthManager? = nil,
        traktClient: TraktClient? = nil,
        mediaResolver: MediaResolver? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        // Try Trakt-powered content first if available
        if let traktClient, let mediaResolver, let traktAuthManager,
           traktAuthManager.isAuthenticated {
            await loadTraktContent(
                traktClient: traktClient,
                mediaResolver: mediaResolver
            )
        }

        // Fall back to / supplement with Overseerr discover endpoints
        if let client = overseerrClient {
            await loadOverseerrContent(client: client)
        } else {
            errorMessage = "Overseerr is not configured"
        }

        deduplicateShelves()
        isLoading = false
    }

    /// Remove duplicate items across all shelves so each title appears only once on screen.
    /// Earlier shelves (recommendations, trending) get priority.
    private func deduplicateShelves() {
        var seen = Set<String>()

        func dedup(_ items: inout [MediaItem]) {
            items = items.filter { seen.insert($0.id).inserted }
        }

        // Priority order: recommendation shelves first, then trending, popular, upcoming
        for i in recommendationShelves.indices {
            var items = recommendationShelves[i].items
            dedup(&items)
            recommendationShelves[i] = RecommendationShelf(
                id: recommendationShelves[i].id,
                title: recommendationShelves[i].title,
                items: items
            )
        }
        dedup(&trendingMovies)
        dedup(&trendingShows)
        dedup(&popularMovies)
        dedup(&popularShows)
        dedup(&upcomingMovies)
        dedup(&upcomingShows)
    }

    // MARK: - Overseerr Fallback

    private func loadOverseerrContent(client: OverseerrClient) async {
        async let trendingTask = Self.fetchTrending(client: client)
        async let moviesTask = Self.fetchDiscoverMovies(client: client)
        async let showsTask = Self.fetchDiscoverTv(client: client)
        async let upMoviesTask = Self.fetchUpcomingMovies(client: client)
        async let upShowsTask = Self.fetchUpcomingTv(client: client)

        let (trending, movies, shows, upMovies, upShows) = await (
            trendingTask, moviesTask, showsTask, upMoviesTask, upShowsTask
        )

        if trendingMovies.isEmpty {
            trendingMovies = trending.filter { $0.mediaType == .movie }
        }
        if trendingShows.isEmpty {
            trendingShows = trending.filter { $0.mediaType == .tv }
        }
        if popularMovies.isEmpty { popularMovies = movies }
        if popularShows.isEmpty { popularShows = shows }
        if upcomingMovies.isEmpty { upcomingMovies = upMovies }
        if upcomingShows.isEmpty { upcomingShows = upShows }
    }

    // Nonisolated static helpers that can run concurrently
    private nonisolated static func fetchTrending(client: OverseerrClient) async -> [MediaItem] {
        (try? await client.discoverTrending())?.results.compactMap { MediaItem.from(result: $0) } ?? []
    }

    private nonisolated static func fetchDiscoverMovies(client: OverseerrClient) async -> [MediaItem] {
        (try? await client.discoverMovies())?.results.compactMap { MediaItem.from(result: $0) } ?? []
    }

    private nonisolated static func fetchDiscoverTv(client: OverseerrClient) async -> [MediaItem] {
        (try? await client.discoverTv())?.results.compactMap { MediaItem.from(result: $0) } ?? []
    }

    private nonisolated static func fetchUpcomingMovies(client: OverseerrClient) async -> [MediaItem] {
        (try? await client.discoverUpcomingMovies())?.results.compactMap { MediaItem.from(result: $0) } ?? []
    }

    private nonisolated static func fetchUpcomingTv(client: OverseerrClient) async -> [MediaItem] {
        (try? await client.discoverUpcomingTv())?.results.compactMap { MediaItem.from(result: $0) } ?? []
    }

    // MARK: - Trakt-Powered Content

    private func loadTraktContent(
        traktClient: TraktClient,
        mediaResolver: MediaResolver
    ) async {
        async let trendingMoviesTask = Self.fetchTraktTrendingMovies(traktClient: traktClient, mediaResolver: mediaResolver)
        async let trendingShowsTask = Self.fetchTraktTrendingShows(traktClient: traktClient, mediaResolver: mediaResolver)
        async let popularMoviesTask = Self.fetchTraktPopularMovies(traktClient: traktClient, mediaResolver: mediaResolver)
        async let popularShowsTask = Self.fetchTraktPopularShows(traktClient: traktClient, mediaResolver: mediaResolver)
        async let recsTask = Self.fetchRecommendationShelves(traktClient: traktClient, mediaResolver: mediaResolver)

        let (tMovies, tShows, pMovies, pShows, recs) = await (
            trendingMoviesTask, trendingShowsTask, popularMoviesTask, popularShowsTask, recsTask
        )

        trendingMovies = tMovies
        trendingShows = tShows
        popularMovies = pMovies
        popularShows = pShows
        recommendationShelves = recs
    }

    private nonisolated static func fetchTraktTrendingMovies(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let trending = try? await traktClient.trendingMovies(limit: 20) else { return [] }
        return await mediaResolver.resolveMovies(trending.map(\.movie))
    }

    private nonisolated static func fetchTraktTrendingShows(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let trending = try? await traktClient.trendingShows(limit: 20) else { return [] }
        return await mediaResolver.resolveShows(trending.map(\.show))
    }

    private nonisolated static func fetchTraktPopularMovies(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let popular = try? await traktClient.popularMovies(limit: 20) else { return [] }
        return await mediaResolver.resolveMovies(popular)
    }

    private nonisolated static func fetchTraktPopularShows(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let popular = try? await traktClient.popularShows(limit: 20) else { return [] }
        return await mediaResolver.resolveShows(popular)
    }

    private nonisolated static func fetchRecommendationShelves(
        traktClient: TraktClient,
        mediaResolver: MediaResolver
    ) async -> [RecommendationShelf] {
        guard let history = try? await traktClient.watchHistory(type: "movies", limit: 3) else { return [] }

        var shelves: [RecommendationShelf] = []

        for historyItem in history {
            guard let movie = historyItem.movie,
                  let tmdbId = movie.ids.tmdb else { continue }

            if let recs = try? await mediaResolver.overseerrClient.movieRecommendations(tmdbId: tmdbId) {
                let items = recs.results.compactMap { MediaItem.from(result: $0) }
                if !items.isEmpty {
                    shelves.append(RecommendationShelf(
                        id: "rec-\(tmdbId)",
                        title: "Because you watched \(movie.title)",
                        items: items
                    ))
                }
            }
        }

        return shelves
    }
}
