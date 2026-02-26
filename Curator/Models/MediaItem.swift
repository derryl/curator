import Foundation

struct MediaItem: Identifiable, Hashable, Sendable {
    let id: String
    let tmdbId: Int
    let mediaType: MediaType
    let title: String
    let year: Int?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let genreIds: [Int]
    var availability: AvailabilityStatus

    enum MediaType: String, Codable, Sendable {
        case movie, tv
    }

    enum AvailabilityStatus: Sendable {
        case unknown, available, partiallyAvailable, processing, pending, none

        /// Sort priority for recommendation shelves: lower = more actionable (can request immediately).
        var requestPriority: Int {
            switch self {
            case .none: 0              // Not in library — can request now
            case .unknown: 1           // Status unclear — likely requestable
            case .partiallyAvailable: 2 // Some content exists
            case .pending: 3           // Already requested
            case .processing: 4        // Being downloaded
            case .available: 5         // Already owned
            }
        }
    }
}

// MARK: - Factory Methods

extension MediaItem {
    static func from(result: OverseerrMediaResult) -> MediaItem? {
        let type: MediaType
        switch result.mediaType {
        case "movie": type = .movie
        case "tv": type = .tv
        default: return nil
        }

        return MediaItem(
            id: "\(type.rawValue)-\(result.id)",
            tmdbId: result.id,
            mediaType: type,
            title: result.displayTitle,
            year: nil,
            overview: result.overview,
            posterPath: result.posterPath,
            backdropPath: result.backdropPath,
            voteAverage: result.voteAverage,
            genreIds: result.genreIds ?? [],
            availability: result.mediaInfo?.availabilityStatus ?? .none
        )
    }

    static func from(movieDetails: OverseerrMovieDetails) -> MediaItem {
        let year: Int? = movieDetails.releaseDate.flatMap { dateString in
            guard dateString.count >= 4 else { return nil }
            return Int(dateString.prefix(4))
        }

        return MediaItem(
            id: "movie-\(movieDetails.id)",
            tmdbId: movieDetails.id,
            mediaType: .movie,
            title: movieDetails.title ?? "Unknown",
            year: year,
            overview: movieDetails.overview,
            posterPath: movieDetails.posterPath,
            backdropPath: movieDetails.backdropPath,
            voteAverage: movieDetails.voteAverage,
            genreIds: movieDetails.genres?.map(\.id) ?? [],
            availability: movieDetails.mediaInfo?.availabilityStatus ?? .none
        )
    }

    static func from(tvDetails: OverseerrTvDetails) -> MediaItem {
        let year: Int? = tvDetails.firstAirDate.flatMap { dateString in
            guard dateString.count >= 4 else { return nil }
            return Int(dateString.prefix(4))
        }

        return MediaItem(
            id: "tv-\(tvDetails.id)",
            tmdbId: tvDetails.id,
            mediaType: .tv,
            title: tvDetails.name ?? "Unknown",
            year: year,
            overview: tvDetails.overview,
            posterPath: tvDetails.posterPath,
            backdropPath: tvDetails.backdropPath,
            voteAverage: tvDetails.voteAverage,
            genreIds: tvDetails.genres?.map(\.id) ?? [],
            availability: tvDetails.mediaInfo?.availabilityStatus ?? .none
        )
    }

    static func from(traktMovie: TraktMovie) -> MediaItem? {
        guard let tmdbId = traktMovie.ids.tmdb else { return nil }
        return MediaItem(
            id: "movie-\(tmdbId)",
            tmdbId: tmdbId,
            mediaType: .movie,
            title: traktMovie.title,
            year: traktMovie.year,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            voteAverage: nil,
            genreIds: [],
            availability: .none
        )
    }

    static func from(traktShow: TraktShow) -> MediaItem? {
        guard let tmdbId = traktShow.ids.tmdb else { return nil }
        return MediaItem(
            id: "tv-\(tmdbId)",
            tmdbId: tmdbId,
            mediaType: .tv,
            title: traktShow.title,
            year: traktShow.year,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            voteAverage: nil,
            genreIds: [],
            availability: .none
        )
    }
}
