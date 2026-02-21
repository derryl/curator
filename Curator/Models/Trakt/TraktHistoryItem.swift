import Foundation

struct TraktHistoryItem: Codable, Sendable {
    let id: Int
    let watchedAt: String
    let action: String
    let type: String
    let movie: TraktMovie?
    let show: TraktShow?

    enum CodingKeys: String, CodingKey {
        case id
        case watchedAt = "watched_at"
        case action, type, movie, show
    }
}
