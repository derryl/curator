import Foundation

struct OverseerrMovieDetails: Codable, Sendable {
    let id: Int
    let title: String?
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let runtime: Int?
    let genres: [OverseerrGenre]?
    let mediaInfo: OverseerrMediaInfo?
    let credits: OverseerrCredits?
}

struct OverseerrGenre: Codable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct OverseerrCredits: Codable, Sendable {
    let cast: [OverseerrCastMember]?
    let crew: [OverseerrCrewMember]?
}

struct OverseerrCastMember: Codable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let character: String?
    let profilePath: String?
}

struct OverseerrCrewMember: Codable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let job: String?
    let department: String?
    let profilePath: String?
}
