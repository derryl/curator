import Foundation

actor MediaResolver {
    let overseerrClient: OverseerrClient

    init(overseerrClient: OverseerrClient) {
        self.overseerrClient = overseerrClient
    }

    /// Resolve an array of TraktMovies into fully-populated MediaItems
    /// by fetching details from Overseerr (which proxies TMDB data + availability)
    func resolveMovies(_ movies: [TraktMovie]) async -> [MediaItem] {
        await withTaskGroup(of: MediaItem?.self) { group in
            for movie in movies {
                guard let tmdbId = movie.ids.tmdb else { continue }
                group.addTask {
                    do {
                        let details = try await self.overseerrClient.movieDetails(tmdbId: tmdbId)
                        return MediaItem.from(movieDetails: details)
                    } catch {
                        // Fall back to Trakt-only data (no images/availability)
                        return MediaItem.from(traktMovie: movie)
                    }
                }
            }

            var results: [MediaItem] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results
        }
    }

    /// Resolve an array of TraktShows into fully-populated MediaItems
    func resolveShows(_ shows: [TraktShow]) async -> [MediaItem] {
        await withTaskGroup(of: MediaItem?.self) { group in
            for show in shows {
                guard let tmdbId = show.ids.tmdb else { continue }
                group.addTask {
                    do {
                        let details = try await self.overseerrClient.tvDetails(tmdbId: tmdbId)
                        return MediaItem.from(tvDetails: details)
                    } catch {
                        return MediaItem.from(traktShow: show)
                    }
                }
            }

            var results: [MediaItem] = []
            for await item in group {
                if let item { results.append(item) }
            }
            return results
        }
    }
}
