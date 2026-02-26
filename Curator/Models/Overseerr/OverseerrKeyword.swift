import Foundation

struct OverseerrKeyword: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct OverseerrKeywordsWrapper: Codable, Sendable {
    let keywords: [OverseerrKeyword]?
    let results: [OverseerrKeyword]?

    /// TMDB nests keywords as `keywords.keywords` for movies and `keywords.results` for TV.
    var allKeywords: [OverseerrKeyword] {
        keywords ?? results ?? []
    }
}
