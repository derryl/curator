import Foundation

struct OverseerrGenreSliderItem: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
    let backdrops: [String]?
}
