import Foundation

struct TraktMovie: Codable, Hashable, Sendable {
    let title: String
    let year: Int?
    let ids: TraktIds
}

struct TraktTrendingMovie: Codable, Sendable {
    let watchers: Int?
    let movie: TraktMovie
}
