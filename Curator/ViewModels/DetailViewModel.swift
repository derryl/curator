import Foundation
import Observation

@MainActor
@Observable
final class DetailViewModel {
    var movieDetails: OverseerrMovieDetails?
    var tvDetails: OverseerrTvDetails?
    var youMightLikeItems: [MediaItem] = []
    var similarItems: [MediaItem] = []
    var recommendedItems: [MediaItem] = []
    var directorShelf: (name: String, items: [MediaItem])?
    var leadActorShelf: (name: String, items: [MediaItem])?
    var isLoading = false
    var errorMessage: String?
    var isRequesting = false
    var requestResult: RequestResult?

    // Quality profiles
    var qualityProfiles: [OverseerrQualityProfile] = []
    var serviceId: Int?
    var rootFolder: String?

    enum RequestResult {
        case success
        case failure(String)
    }

    func loadMovieDetails(tmdbId: Int, using client: OverseerrClient) async {
        isLoading = true
        errorMessage = nil

        do {
            async let detailsTask = client.movieDetails(tmdbId: tmdbId)
            async let similarTask = client.movieSimilar(tmdbId: tmdbId)
            async let recsTask = client.movieRecommendations(tmdbId: tmdbId)

            let (details, similar, recs) = try await (detailsTask, similarTask, recsTask)

            movieDetails = details

            let similarMediaItems = similar.results.compactMap { MediaItem.from(result: $0) }
            let recommendedMediaItems = recs.results.compactMap { MediaItem.from(result: $0) }

            let movieGenreIds = Set(details.genres?.map(\.id) ?? [])
            youMightLikeItems = mergeAndFilter(
                similar: similarMediaItems,
                recommended: recommendedMediaItems,
                genreIds: movieGenreIds
            )

            // Fetch person-based shelves and quality profiles concurrently
            async let personShelvesTask: Void = loadPersonShelves(
                credits: details.credits,
                currentTmdbId: tmdbId,
                isMovie: true,
                using: client
            )
            async let profilesTask: Void = loadQualityProfiles(for: "movie", using: client)
            _ = await (personShelvesTask, profilesTask)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadTvDetails(tmdbId: Int, using client: OverseerrClient) async {
        isLoading = true
        errorMessage = nil

        do {
            async let detailsTask = client.tvDetails(tmdbId: tmdbId)
            async let similarTask = client.tvSimilar(tmdbId: tmdbId)
            async let recsTask = client.tvRecommendations(tmdbId: tmdbId)

            let (details, similar, recs) = try await (detailsTask, similarTask, recsTask)

            tvDetails = details

            let similarMediaItems = similar.results.compactMap { MediaItem.from(result: $0) }
            let recommendedMediaItems = recs.results.compactMap { MediaItem.from(result: $0) }

            let tvGenreIds = Set(details.genres?.map(\.id) ?? [])
            youMightLikeItems = mergeAndFilter(
                similar: similarMediaItems,
                recommended: recommendedMediaItems,
                genreIds: tvGenreIds
            )

            // Fetch person-based shelves and quality profiles concurrently
            async let personShelvesTask: Void = loadPersonShelves(
                credits: details.credits,
                currentTmdbId: tmdbId,
                isMovie: false,
                using: client
            )
            async let profilesTask: Void = loadQualityProfiles(for: "tv", using: client)
            _ = await (personShelvesTask, profilesTask)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func requestMedia(
        mediaType: String,
        mediaId: Int,
        profileId: Int? = nil,
        using client: OverseerrClient
    ) async {
        isRequesting = true
        requestResult = nil

        do {
            _ = try await client.createRequest(
                mediaType: mediaType,
                mediaId: mediaId,
                serverId: serviceId,
                profileId: profileId,
                rootFolder: rootFolder
            )
            requestResult = .success

            // Refresh details to get updated availability
            if mediaType == "movie" {
                if let updated = try? await client.movieDetails(tmdbId: mediaId) {
                    movieDetails = updated
                }
            } else {
                if let updated = try? await client.tvDetails(tmdbId: mediaId) {
                    tvDetails = updated
                }
            }
        } catch {
            requestResult = .failure(error.localizedDescription)
        }

        isRequesting = false
    }

    // MARK: - Private

    /// Merge similar + recommended, deduplicate, and filter out items that share no genres with the current title.
    /// Recommended items are prioritized (appear first). Items without genre data are kept.
    private func mergeAndFilter(
        similar: [MediaItem],
        recommended: [MediaItem],
        genreIds: Set<Int>
    ) -> [MediaItem] {
        var seen = Set<String>()
        var merged: [MediaItem] = []

        // Recommended first (higher quality matches)
        for item in recommended {
            guard !seen.contains(item.id) else { continue }
            seen.insert(item.id)
            merged.append(item)
        }

        // Then similar
        for item in similar {
            guard !seen.contains(item.id) else { continue }
            seen.insert(item.id)
            merged.append(item)
        }

        // If we don't know the current title's genres, return everything
        guard !genreIds.isEmpty else { return merged }

        return merged.filter { item in
            // Keep items with no genre data (benefit of the doubt)
            guard !item.genreIds.isEmpty else { return true }
            // Keep items that share at least one genre
            return !genreIds.isDisjoint(with: item.genreIds)
        }
    }

    /// Load "More from [Director]" and "More with [Lead Actor]" shelves from credits.
    private func loadPersonShelves(
        credits: OverseerrCredits?,
        currentTmdbId: Int,
        isMovie: Bool,
        using client: OverseerrClient
    ) async {
        guard let credits else { return }

        // Find the key creative: director for movies, executive producer for TV
        let keyCreative: OverseerrCrewMember? = credits.crew?.first {
            isMovie ? $0.job == "Director" : $0.job == "Executive Producer"
        }

        // Find the first-billed cast member
        let leadActor: OverseerrCastMember? = credits.cast?.first

        // Fetch both filmographies concurrently
        async let directorTask = fetchPersonFilmography(
            person: keyCreative.map { (id: $0.id, name: $0.name ?? "Unknown") },
            currentTmdbId: currentTmdbId,
            using: client
        )
        async let actorTask = fetchPersonFilmography(
            person: leadActor.map { (id: $0.id, name: $0.name ?? "Unknown") },
            currentTmdbId: currentTmdbId,
            using: client
        )

        let (directorResult, actorResult) = await (directorTask, actorTask)
        directorShelf = directorResult
        leadActorShelf = actorResult
    }

    /// Fetch a person's combined credits and return as a named filmography shelf.
    private nonisolated func fetchPersonFilmography(
        person: (id: Int, name: String)?,
        currentTmdbId: Int,
        using client: OverseerrClient
    ) async -> (name: String, items: [MediaItem])? {
        guard let person else { return nil }

        guard let credits = try? await client.personCombinedCredits(personId: person.id) else {
            return nil
        }

        var seen = Set<String>()
        var items: [MediaItem] = []

        // Include both cast and crew credits
        if let cast = credits.cast {
            for credit in cast {
                guard credit.id != currentTmdbId,
                      let mediaType = credit.mediaType,
                      let item = Self.mediaItemFrom(credit: credit, mediaType: mediaType),
                      seen.insert(item.id).inserted else { continue }
                items.append(item)
            }
        }
        if let crew = credits.crew {
            for credit in crew {
                guard credit.id != currentTmdbId,
                      let mediaType = credit.mediaType,
                      let item = Self.mediaItemFrom(crewCredit: credit, mediaType: mediaType),
                      seen.insert(item.id).inserted else { continue }
                items.append(item)
            }
        }

        // Sort by rating descending, cap at 15
        items.sort { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        items = Array(items.prefix(15))

        guard !items.isEmpty else { return nil }
        return (name: person.name, items: items)
    }

    /// Convert a cast credit into a MediaItem. Shared logic extracted from PersonViewModel.
    nonisolated static func mediaItemFrom(credit: PersonCreditCast, mediaType: String) -> MediaItem? {
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

    /// Convert a crew credit into a MediaItem. Shared logic extracted from PersonViewModel.
    nonisolated static func mediaItemFrom(crewCredit: PersonCreditCrew, mediaType: String) -> MediaItem? {
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

    private func loadQualityProfiles(for mediaType: String, using client: OverseerrClient) async {
        do {
            if mediaType == "movie" {
                let services = try await client.radarrServices()
                if let defaultService = services.first(where: { $0.isDefault == true }) ?? services.first {
                    let details = try await client.radarrServiceDetails(serverId: defaultService.id)
                    qualityProfiles = details.profiles
                    serviceId = defaultService.id
                    rootFolder = defaultService.activeDirectory
                }
            } else {
                let services = try await client.sonarrServices()
                if let defaultService = services.first(where: { $0.isDefault == true }) ?? services.first {
                    let details = try await client.sonarrServiceDetails(serverId: defaultService.id)
                    qualityProfiles = details.profiles
                    serviceId = defaultService.id
                    rootFolder = defaultService.activeDirectory
                }
            }
        } catch {
            // Non-fatal — request will just use server defaults
            qualityProfiles = []
        }
    }
}
