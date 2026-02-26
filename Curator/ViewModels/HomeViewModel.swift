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
    var topRatedMovies: [MediaItem] = []
    var topRatedShows: [MediaItem] = []
    var anticipatedMovies: [MediaItem] = []
    var anticipatedShows: [MediaItem] = []
    var mostWatchedMovies: [MediaItem] = []
    var mostWatchedShows: [MediaItem] = []
    var hiddenGems: [MediaItem] = []
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

        deriveTopRatedShelves()
        deriveHiddenGems()
        deduplicateShelves()
        isLoading = false
    }

    /// Derive "Top Rated" shelves from popular content — titles with voteAverage >= 7.5, sorted by rating.
    func deriveTopRatedShelves() {
        let allMovies = popularMovies + trendingMovies + upcomingMovies
        topRatedMovies = Array(
            allMovies
                .filter { ($0.voteAverage ?? 0) >= 7.5 }
                .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
                .prefix(15)
        )

        let allShows = popularShows + trendingShows + upcomingShows
        topRatedShows = Array(
            allShows
                .filter { ($0.voteAverage ?? 0) >= 7.5 }
                .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
                .prefix(15)
        )
    }

    /// Surface well-rated items from recommendation shelves that don't appear in mainstream shelves.
    func deriveHiddenGems() {
        let mainstreamIds = Set(
            (trendingMovies + trendingShows + popularMovies + popularShows)
                .map(\.id)
        )

        let allRecommended = recommendationShelves.flatMap(\.items)
        hiddenGems = Array(
            allRecommended
                .filter { !mainstreamIds.contains($0.id) && ($0.voteAverage ?? 0) >= 7.0 }
                .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
                .prefix(15)
        )
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
        dedup(&topRatedMovies)
        dedup(&topRatedShows)
        dedup(&anticipatedMovies)
        dedup(&anticipatedShows)
        dedup(&mostWatchedMovies)
        dedup(&mostWatchedShows)
        dedup(&hiddenGems)
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
        // Build watched IDs first — all recommendation sources need this
        let watchedIds = await Self.buildWatchedIds(traktClient: traktClient)

        // Fan out all shelf fetches concurrently
        async let trendingMoviesTask = Self.fetchTraktTrendingMovies(traktClient: traktClient, mediaResolver: mediaResolver)
        async let trendingShowsTask = Self.fetchTraktTrendingShows(traktClient: traktClient, mediaResolver: mediaResolver)
        async let popularMoviesTask = Self.fetchTraktPopularMovies(traktClient: traktClient, mediaResolver: mediaResolver)
        async let popularShowsTask = Self.fetchTraktPopularShows(traktClient: traktClient, mediaResolver: mediaResolver)
        async let anticipatedMoviesTask = Self.fetchTraktAnticipatedMovies(traktClient: traktClient, mediaResolver: mediaResolver)
        async let anticipatedShowsTask = Self.fetchTraktAnticipatedShows(traktClient: traktClient, mediaResolver: mediaResolver)
        async let mostWatchedMoviesTask = Self.fetchTraktMostWatchedMovies(traktClient: traktClient, mediaResolver: mediaResolver)
        async let mostWatchedShowsTask = Self.fetchTraktMostWatchedShows(traktClient: traktClient, mediaResolver: mediaResolver)
        async let couchMoneyTask = Self.fetchCouchMoneyShelves(traktClient: traktClient, mediaResolver: mediaResolver, watchedTmdbIds: watchedIds)
        async let traktMLTask = Self.fetchTraktMLShelves(traktClient: traktClient, mediaResolver: mediaResolver, watchedTmdbIds: watchedIds)
        async let becauseTask = Self.fetchBecauseYouWatchedShelves(traktClient: traktClient, mediaResolver: mediaResolver, watchedTmdbIds: watchedIds)

        let (tMovies, tShows, pMovies, pShows, aMovies, aShows, mwMovies, mwShows, couchMoney, traktML, because) = await (
            trendingMoviesTask, trendingShowsTask, popularMoviesTask, popularShowsTask,
            anticipatedMoviesTask, anticipatedShowsTask,
            mostWatchedMoviesTask, mostWatchedShowsTask,
            couchMoneyTask, traktMLTask, becauseTask
        )

        trendingMovies = tMovies
        trendingShows = tShows
        popularMovies = pMovies
        popularShows = pShows
        anticipatedMovies = aMovies
        anticipatedShows = aShows
        mostWatchedMovies = mwMovies
        mostWatchedShows = mwShows
        recommendationShelves = couchMoney + traktML + because
    }

    // MARK: - Watched IDs

    private nonisolated static func buildWatchedIds(traktClient: TraktClient) async -> Set<Int> {
        async let movieHistory = (try? await traktClient.watchHistory(type: "movies", limit: 200)) ?? []
        async let showHistory = (try? await traktClient.watchHistory(type: "shows", limit: 200)) ?? []

        let (movies, shows) = await (movieHistory, showHistory)
        var ids = Set<Int>()
        for item in movies {
            if let tmdbId = item.movie?.ids.tmdb { ids.insert(tmdbId) }
        }
        for item in shows {
            if let tmdbId = item.show?.ids.tmdb { ids.insert(tmdbId) }
        }
        return ids
    }

    // MARK: - CouchMoney Shelves

    private nonisolated static func fetchCouchMoneyShelves(
        traktClient: TraktClient,
        mediaResolver: MediaResolver,
        watchedTmdbIds: Set<Int>
    ) async -> [RecommendationShelf] {
        async let movieItems = (try? await traktClient.userListItems(
            username: Constants.CouchMoney.username,
            listSlug: Constants.CouchMoney.movieListSlug,
            type: "movies",
            limit: 20
        )) ?? []
        async let showItems = (try? await traktClient.userListItems(
            username: Constants.CouchMoney.username,
            listSlug: Constants.CouchMoney.showListSlug,
            type: "shows",
            limit: 20
        )) ?? []

        let (movies, shows) = await (movieItems, showItems)

        let traktMovies = movies.compactMap(\.movie)
        let traktShows = shows.compactMap(\.show)

        async let resolvedMovies = mediaResolver.resolveAndFilterMovies(traktMovies, watchedTmdbIds: watchedTmdbIds)
        async let resolvedShows = mediaResolver.resolveAndFilterShows(traktShows, watchedTmdbIds: watchedTmdbIds)

        let (movieResults, showResults) = await (resolvedMovies, resolvedShows)

        var shelves: [RecommendationShelf] = []
        if !movieResults.isEmpty {
            shelves.append(RecommendationShelf(
                id: "couchmoney-movies",
                title: "Recommended Movies",
                items: sortByRequestPriority(movieResults)
            ))
        }
        if !showResults.isEmpty {
            shelves.append(RecommendationShelf(
                id: "couchmoney-shows",
                title: "Recommended Shows",
                items: sortByRequestPriority(showResults)
            ))
        }
        return shelves
    }

    // MARK: - Trakt ML Shelves

    private nonisolated static func fetchTraktMLShelves(
        traktClient: TraktClient,
        mediaResolver: MediaResolver,
        watchedTmdbIds: Set<Int>
    ) async -> [RecommendationShelf] {
        async let recMovies = (try? await traktClient.recommendedMovies(
            limit: 20, ignoreWatched: true, ignoreCollected: true
        )) ?? []
        async let recShows = (try? await traktClient.recommendedShows(
            limit: 20, ignoreWatched: true, ignoreCollected: true
        )) ?? []

        let (movies, shows) = await (recMovies, recShows)

        async let resolvedMovies = mediaResolver.resolveAndFilterMovies(movies, watchedTmdbIds: watchedTmdbIds)
        async let resolvedShows = mediaResolver.resolveAndFilterShows(shows, watchedTmdbIds: watchedTmdbIds)

        let (movieResults, showResults) = await (resolvedMovies, resolvedShows)

        var shelves: [RecommendationShelf] = []
        if !movieResults.isEmpty {
            shelves.append(RecommendationShelf(
                id: "trakt-ml-movies",
                title: "For You: Movies",
                items: sortByRequestPriority(movieResults)
            ))
        }
        if !showResults.isEmpty {
            shelves.append(RecommendationShelf(
                id: "trakt-ml-shows",
                title: "For You: Shows",
                items: sortByRequestPriority(showResults)
            ))
        }
        return shelves
    }

    // MARK: - "Because you watched" Shelves

    private nonisolated static func fetchBecauseYouWatchedShelves(
        traktClient: TraktClient,
        mediaResolver: MediaResolver,
        watchedTmdbIds: Set<Int>
    ) async -> [RecommendationShelf] {
        // Fetch deeper history for both movies and shows, then interleave
        async let movieHistory = (try? await traktClient.watchHistory(type: "movies", limit: 15)) ?? []
        async let showHistory = (try? await traktClient.watchHistory(type: "shows", limit: 15)) ?? []

        let (movies, shows) = await (movieHistory, showHistory)

        // Interleave movie and show seeds for variety
        var seeds: [(title: String, tmdbId: Int, mediaType: MediaItem.MediaType, slug: String?)] = []
        let maxSeeds = max(movies.count, shows.count)
        for i in 0..<maxSeeds {
            if i < movies.count, let movie = movies[i].movie, let tmdbId = movie.ids.tmdb {
                seeds.append((movie.title, tmdbId, .movie, movie.ids.slug))
            }
            if i < shows.count, let show = shows[i].show, let tmdbId = show.ids.tmdb {
                seeds.append((show.title, tmdbId, .tv, show.ids.slug))
            }
        }

        // Deduplicate franchises by slug prefix (e.g., "harry-potter-*" → keep only first)
        var seenPrefixes = Set<String>()
        let dedupedSeeds = seeds.filter { seed in
            let prefix = franchisePrefix(slug: seed.slug)
            if let prefix {
                return seenPrefixes.insert(prefix).inserted
            }
            return true // no slug = keep it
        }

        var shelves: [RecommendationShelf] = []
        let maxShelves = 2

        for seed in dedupedSeeds {
            guard shelves.count < maxShelves else { break }

            let items: [MediaItem]
            switch seed.mediaType {
            case .movie:
                guard let recs = try? await mediaResolver.overseerrClient.movieRecommendations(tmdbId: seed.tmdbId) else { continue }
                let all = recs.results.compactMap { MediaItem.from(result: $0) }
                items = all.filter { !watchedTmdbIds.contains($0.tmdbId) && $0.availability != .available }
            case .tv:
                guard let recs = try? await mediaResolver.overseerrClient.tvRecommendations(tmdbId: seed.tmdbId) else { continue }
                let all = recs.results.compactMap { MediaItem.from(result: $0) }
                items = all.filter { !watchedTmdbIds.contains($0.tmdbId) && $0.availability != .available }
            }

            // Require at least 3 results for a meaningful shelf
            if items.count >= 3 {
                shelves.append(RecommendationShelf(
                    id: "rec-\(seed.tmdbId)",
                    title: "Because you watched \(seed.title)",
                    items: sortByRequestPriority(items)
                ))
            }
        }

        return shelves
    }

    /// Extract a franchise prefix from a Trakt slug.
    /// e.g., "harry-potter-and-the-goblet-of-fire" → "harry-potter"
    /// Returns nil if no clear franchise prefix is detected.
    private nonisolated static func franchisePrefix(slug: String?) -> String? {
        guard let slug else { return nil }
        let parts = slug.split(separator: "-")
        // Need at least 3 parts to have a meaningful prefix
        guard parts.count >= 3 else { return nil }
        // Use first two words as franchise prefix
        return parts.prefix(2).joined(separator: "-")
    }

    /// Sort items so the most requestable ones appear first within a shelf.
    nonisolated static func sortByRequestPriority(_ items: [MediaItem]) -> [MediaItem] {
        items.sorted { $0.availability.requestPriority < $1.availability.requestPriority }
    }

    // MARK: - Trending & Popular (unchanged — no filtering)

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

    // MARK: - Anticipated & Most Watched

    private nonisolated static func fetchTraktAnticipatedMovies(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let anticipated = try? await traktClient.anticipatedMovies(limit: 20) else { return [] }
        return await mediaResolver.resolveMovies(anticipated.map(\.movie))
    }

    private nonisolated static func fetchTraktAnticipatedShows(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let anticipated = try? await traktClient.anticipatedShows(limit: 20) else { return [] }
        return await mediaResolver.resolveShows(anticipated.map(\.show))
    }

    private nonisolated static func fetchTraktMostWatchedMovies(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let watched = try? await traktClient.mostWatchedMovies(period: "weekly", limit: 20) else { return [] }
        return await mediaResolver.resolveMovies(watched.map(\.movie))
    }

    private nonisolated static func fetchTraktMostWatchedShows(traktClient: TraktClient, mediaResolver: MediaResolver) async -> [MediaItem] {
        guard let watched = try? await traktClient.mostWatchedShows(period: "weekly", limit: 20) else { return [] }
        return await mediaResolver.resolveShows(watched.map(\.show))
    }
}
