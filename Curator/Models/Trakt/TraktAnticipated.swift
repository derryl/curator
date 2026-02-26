import Foundation

struct TraktAnticipatedMovie: Codable, Sendable {
    let listCount: Int
    let movie: TraktMovie

    enum CodingKeys: String, CodingKey {
        case listCount = "list_count"
        case movie
    }
}

struct TraktAnticipatedShow: Codable, Sendable {
    let listCount: Int
    let show: TraktShow

    enum CodingKeys: String, CodingKey {
        case listCount = "list_count"
        case show
    }
}
