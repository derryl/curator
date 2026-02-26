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
    let relatedVideos: [OverseerrVideo]?
    let keywords: [OverseerrKeyword]
}

extension OverseerrMovieDetails: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, originalTitle, overview, posterPath, backdropPath
        case voteAverage, releaseDate, runtime, genres, mediaInfo, credits
        case relatedVideos, keywords
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
        do {
            relatedVideos = try container.decodeIfPresent([OverseerrVideo].self, forKey: .relatedVideos)
        } catch {
            relatedVideos = nil
        }
        // TMDB nests keywords as { keywords: { keywords: [...] } } for movies
        do {
            let wrapper = try container.decodeIfPresent(OverseerrKeywordsWrapper.self, forKey: .keywords)
            keywords = wrapper?.allKeywords ?? []
        } catch {
            keywords = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(originalTitle, forKey: .originalTitle)
        try container.encodeIfPresent(overview, forKey: .overview)
        try container.encodeIfPresent(posterPath, forKey: .posterPath)
        try container.encodeIfPresent(backdropPath, forKey: .backdropPath)
        try container.encodeIfPresent(voteAverage, forKey: .voteAverage)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(runtime, forKey: .runtime)
        try container.encodeIfPresent(genres, forKey: .genres)
        try container.encodeIfPresent(mediaInfo, forKey: .mediaInfo)
        try container.encodeIfPresent(credits, forKey: .credits)
        try container.encodeIfPresent(relatedVideos, forKey: .relatedVideos)
        let wrapper = OverseerrKeywordsWrapper(keywords: keywords, results: nil)
        try container.encode(wrapper, forKey: .keywords)
    }
}

struct OverseerrVideo: Codable, Sendable, Identifiable {
    var id: String { key ?? UUID().uuidString }
    let url: String?
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
