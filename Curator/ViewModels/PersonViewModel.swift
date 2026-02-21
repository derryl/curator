import Foundation
import Observation

@MainActor
@Observable
final class PersonViewModel {
    var personDetails: OverseerrPersonDetails?
    var creditSections: [CreditSection] = []
    var isLoading = false
    var errorMessage: String?

    struct CreditSection: Identifiable {
        let id: String
        let title: String
        var items: [MediaItem]
    }

    func loadPerson(personId: Int, using client: OverseerrClient) async {
        isLoading = true
        errorMessage = nil

        do {
            async let detailsTask = client.personDetails(personId: personId)
            async let creditsTask = client.personCombinedCredits(personId: personId)

            let (details, credits) = try await (detailsTask, creditsTask)

            personDetails = details
            creditSections = buildSections(from: credits)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func buildSections(from credits: OverseerrPersonCombinedCredits) -> [CreditSection] {
        var sections: [CreditSection] = []
        var seenIds = Set<String>()

        // Cast → "Acted in"
        if let cast = credits.cast, !cast.isEmpty {
            var items: [MediaItem] = []
            for credit in cast {
                guard let mediaType = credit.mediaType,
                      let item = mediaItemFrom(credit: credit, mediaType: mediaType) else { continue }
                guard !seenIds.contains(item.id) else { continue }
                seenIds.insert(item.id)
                items.append(item)
            }
            if !items.isEmpty {
                sections.append(CreditSection(id: "acted", title: "Acted in", items: items))
            }
        }

        // Crew → group by department
        if let crew = credits.crew, !crew.isEmpty {
            var departmentMap: [(key: String, title: String, items: [MediaItem])] = []
            let departmentOrder = [
                ("Directing", "Directed"),
                ("Production", "Produced"),
                ("Writing", "Writing"),
            ]

            // Reset seen IDs per section so same title can appear in multiple roles
            for (dept, title) in departmentOrder {
                var sectionSeenIds = Set<String>()
                var items: [MediaItem] = []
                for credit in crew where credit.department == dept {
                    guard let mediaType = credit.mediaType,
                          let item = mediaItemFrom(crewCredit: credit, mediaType: mediaType) else { continue }
                    guard !sectionSeenIds.contains(item.id) else { continue }
                    sectionSeenIds.insert(item.id)
                    items.append(item)
                }
                if !items.isEmpty {
                    departmentMap.append((key: dept, title: title, items: items))
                }
            }

            // Remaining departments not in the predefined list
            let knownDepts = Set(departmentOrder.map(\.0))
            var otherItems: [MediaItem] = []
            var otherSeenIds = Set<String>()
            for credit in crew where !knownDepts.contains(credit.department ?? "") {
                guard let mediaType = credit.mediaType,
                      let item = mediaItemFrom(crewCredit: credit, mediaType: mediaType) else { continue }
                guard !otherSeenIds.contains(item.id) else { continue }
                otherSeenIds.insert(item.id)
                otherItems.append(item)
            }
            if !otherItems.isEmpty {
                departmentMap.append((key: "other", title: "Crew", items: otherItems))
            }

            for entry in departmentMap {
                sections.append(CreditSection(id: entry.key, title: entry.title, items: entry.items))
            }
        }

        return sections
    }

    private func mediaItemFrom(credit: PersonCreditCast, mediaType: String) -> MediaItem? {
        let type: MediaItem.MediaType
        switch mediaType {
        case "movie": type = .movie
        case "tv": type = .tv
        default: return nil
        }

        let year: Int? = (credit.releaseDate ?? credit.firstAirDate).flatMap { dateString in
            guard dateString.count >= 4 else { return nil }
            return Int(dateString.prefix(4))
        }

        return MediaItem(
            id: "\(type.rawValue)-\(credit.id)",
            tmdbId: credit.id,
            mediaType: type,
            title: credit.displayTitle,
            year: year,
            overview: nil,
            posterPath: credit.posterPath,
            backdropPath: credit.backdropPath,
            voteAverage: credit.voteAverage,
            genreIds: [],
            availability: credit.mediaInfo?.availabilityStatus ?? .none
        )
    }

    private func mediaItemFrom(crewCredit: PersonCreditCrew, mediaType: String) -> MediaItem? {
        let type: MediaItem.MediaType
        switch mediaType {
        case "movie": type = .movie
        case "tv": type = .tv
        default: return nil
        }

        let year: Int? = (crewCredit.releaseDate ?? crewCredit.firstAirDate).flatMap { dateString in
            guard dateString.count >= 4 else { return nil }
            return Int(dateString.prefix(4))
        }

        return MediaItem(
            id: "\(type.rawValue)-\(crewCredit.id)",
            tmdbId: crewCredit.id,
            mediaType: type,
            title: crewCredit.displayTitle,
            year: year,
            overview: nil,
            posterPath: crewCredit.posterPath,
            backdropPath: crewCredit.backdropPath,
            voteAverage: crewCredit.voteAverage,
            genreIds: [],
            availability: crewCredit.mediaInfo?.availabilityStatus ?? .none
        )
    }
}
