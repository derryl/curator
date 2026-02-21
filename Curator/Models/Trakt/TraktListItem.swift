import Foundation

struct TraktListItem: Codable, Sendable {
    let rank: Int
    let id: Int
    let listedAt: String
    let type: String
    let movie: TraktMovie?
    let show: TraktShow?

    enum CodingKeys: String, CodingKey {
        case rank, id
        case listedAt = "listed_at"
        case type, movie, show
    }
}
