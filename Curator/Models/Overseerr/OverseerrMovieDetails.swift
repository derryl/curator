import Foundation

struct OverseerrMovieDetails: Sendable {
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
    let relatedVideos: OverseerrRelatedVideos?
}

extension OverseerrMovieDetails: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, originalTitle, overview, posterPath, backdropPath
        case voteAverage, releaseDate, runtime, genres, mediaInfo, credits
        case relatedVideos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        genres = try container.decodeIfPresent([OverseerrGenre].self, forKey: .genres)
        mediaInfo = try container.decodeIfPresent(OverseerrMediaInfo.self, forKey: .mediaInfo)
        credits = try container.decodeIfPresent(OverseerrCredits.self, forKey: .credits)
        // Decode relatedVideos with try? so a format mismatch doesn't fail the entire response
        relatedVideos = try? container.decodeIfPresent(OverseerrRelatedVideos.self, forKey: .relatedVideos)
    }
}

struct OverseerrRelatedVideos: Codable, Sendable {
    let results: [OverseerrVideo]?
}

struct OverseerrVideo: Codable, Sendable, Identifiable {
    let id: String
    let key: String?
    let name: String?
    let site: String?
    let type: String?
    let size: Int?
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
