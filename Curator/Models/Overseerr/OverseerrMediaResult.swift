import Foundation

struct OverseerrMediaResult: Codable, Identifiable, Sendable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let voteAverage: Double?
    let genreIds: [Int]?
    let mediaInfo: OverseerrMediaInfo?

    var displayTitle: String {
        title ?? name ?? originalTitle ?? originalName ?? "Unknown"
    }
}

struct OverseerrPagedResponse<T: Codable & Sendable>: Codable, Sendable {
    let page: Int
    let totalPages: Int
    let totalResults: Int
    let results: [T]
}
