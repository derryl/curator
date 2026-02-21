import Foundation

struct OverseerrMediaInfo: Codable, Hashable, Sendable {
    let id: Int?
    let mediaType: String?
    let status: Int?
    let requests: [OverseerrMediaRequest]?

    var availabilityStatus: MediaItem.AvailabilityStatus {
        switch status {
        case 1: .unknown
        case 2: .pending
        case 3: .processing
        case 4: .partiallyAvailable
        case 5: .available
        default: .none
        }
    }
}
