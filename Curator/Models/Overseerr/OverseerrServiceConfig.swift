import Foundation

struct OverseerrServiceInfo: Codable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let is4k: Bool?
    let isDefault: Bool?
    let activeProfileId: Int?
    let activeDirectory: String?
}

struct OverseerrServiceDetails: Codable, Sendable {
    let server: OverseerrServiceInfo
    let profiles: [OverseerrQualityProfile]
}

struct OverseerrQualityProfile: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}
