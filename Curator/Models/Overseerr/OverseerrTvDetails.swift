import Foundation

struct OverseerrTvDetails: Sendable {
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
    let relatedVideos: [OverseerrVideo]?
    let keywords: [OverseerrKeyword]
}

extension OverseerrTvDetails: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, originalName, overview, posterPath, backdropPath
        case voteAverage, firstAirDate, numberOfSeasons, numberOfEpisodes
        case genres, mediaInfo, credits, seasons, relatedVideos, keywords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        originalName = try container.decodeIfPresent(String.self, forKey: .originalName)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        numberOfSeasons = try container.decodeIfPresent(Int.self, forKey: .numberOfSeasons)
        numberOfEpisodes = try container.decodeIfPresent(Int.self, forKey: .numberOfEpisodes)
        genres = try container.decodeIfPresent([OverseerrGenre].self, forKey: .genres)
        mediaInfo = try container.decodeIfPresent(OverseerrMediaInfo.self, forKey: .mediaInfo)
        credits = try container.decodeIfPresent(OverseerrCredits.self, forKey: .credits)
        seasons = try container.decodeIfPresent([OverseerrSeason].self, forKey: .seasons)
        do {
            relatedVideos = try container.decodeIfPresent([OverseerrVideo].self, forKey: .relatedVideos)
        } catch {
            relatedVideos = nil
        }
        // TMDB nests keywords as { keywords: { results: [...] } } for TV
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
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(originalName, forKey: .originalName)
        try container.encodeIfPresent(overview, forKey: .overview)
        try container.encodeIfPresent(posterPath, forKey: .posterPath)
        try container.encodeIfPresent(backdropPath, forKey: .backdropPath)
        try container.encodeIfPresent(voteAverage, forKey: .voteAverage)
        try container.encodeIfPresent(firstAirDate, forKey: .firstAirDate)
        try container.encodeIfPresent(numberOfSeasons, forKey: .numberOfSeasons)
        try container.encodeIfPresent(numberOfEpisodes, forKey: .numberOfEpisodes)
        try container.encodeIfPresent(genres, forKey: .genres)
        try container.encodeIfPresent(mediaInfo, forKey: .mediaInfo)
        try container.encodeIfPresent(credits, forKey: .credits)
        try container.encodeIfPresent(seasons, forKey: .seasons)
        try container.encodeIfPresent(relatedVideos, forKey: .relatedVideos)
        let wrapper = OverseerrKeywordsWrapper(keywords: nil, results: keywords)
        try container.encode(wrapper, forKey: .keywords)
    }
}

struct OverseerrSeason: Codable, Identifiable, Sendable {
    let id: Int
    let seasonNumber: Int
    let name: String?
    let episodeCount: Int?
    let overview: String?
    let posterPath: String?
}
