import Foundation

struct OverseerrTvDetails: Codable, Sendable {
    let id: Int
    let name: String?
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let firstAirDate: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let genres: [OverseerrGenre]?
    let mediaInfo: OverseerrMediaInfo?
    let credits: OverseerrCredits?
    let seasons: [OverseerrSeason]?
}

struct OverseerrSeason: Codable, Identifiable, Sendable {
    let id: Int
    let seasonNumber: Int
    let name: String?
    let episodeCount: Int?
    let overview: String?
    let posterPath: String?
}
