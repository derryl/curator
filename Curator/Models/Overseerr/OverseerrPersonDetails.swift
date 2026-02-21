import Foundation

struct OverseerrPersonDetails: Codable, Sendable {
    let id: Int
    let name: String?
    let biography: String?
    let profilePath: String?
    let knownForDepartment: String?
    let birthday: String?
    let placeOfBirth: String?
}

struct OverseerrPersonCombinedCredits: Codable, Sendable {
    let id: Int
    let cast: [PersonCreditCast]?
    let crew: [PersonCreditCrew]?
}

struct PersonCreditCast: Codable, Identifiable, Sendable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let character: String?
    let releaseDate: String?
    let firstAirDate: String?
    let mediaInfo: OverseerrMediaInfo?

    var displayTitle: String {
        title ?? name ?? "Unknown"
    }
}

struct PersonCreditCrew: Codable, Identifiable, Sendable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let job: String?
    let department: String?
    let releaseDate: String?
    let firstAirDate: String?
    let mediaInfo: OverseerrMediaInfo?

    var displayTitle: String {
        title ?? name ?? "Unknown"
    }
}
