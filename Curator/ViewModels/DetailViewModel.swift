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

            // Fetch quality profiles from Radarr
            await loadQualityProfiles(for: "movie", using: client)
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

            // Fetch quality profiles from Sonarr
            await loadQualityProfiles(for: "tv", using: client)
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
