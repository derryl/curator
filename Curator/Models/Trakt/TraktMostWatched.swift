import Foundation

struct TraktMostWatchedMovie: Codable, Sendable {
    let watcherCount: Int
    let playCount: Int
    let movie: TraktMovie

    enum CodingKeys: String, CodingKey {
        case watcherCount = "watcher_count"
        case playCount = "play_count"
        case movie
    }
}

struct TraktMostWatchedShow: Codable, Sendable {
    let watcherCount: Int
    let playCount: Int
    let show: TraktShow

    enum CodingKeys: String, CodingKey {
        case watcherCount = "watcher_count"
        case playCount = "play_count"
        case show
    }
}
