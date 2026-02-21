import Foundation

struct OverseerrMediaRequest: Codable, Hashable, Sendable {
    let id: Int
    let status: Int
    let mediaType: String?
    let createdAt: String?
    let updatedAt: String?
}
