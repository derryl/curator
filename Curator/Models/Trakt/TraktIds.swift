import Foundation

struct TraktIds: Codable, Hashable, Sendable {
    let trakt: Int?
    let slug: String?
    let imdb: String?
    let tmdb: Int?
}
