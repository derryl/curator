import Foundation

struct OverseerrUser: Codable, Identifiable, Sendable {
    let id: Int
    let email: String?
    let displayName: String?
    let avatar: String?
}
