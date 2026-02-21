import Foundation

struct TraktShow: Codable, Hashable, Sendable {
    let title: String
    let year: Int?
    let ids: TraktIds
}

struct TraktTrendingShow: Codable, Sendable {
    let watchers: Int?
    let show: TraktShow
}
