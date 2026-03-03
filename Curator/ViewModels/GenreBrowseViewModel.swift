import Foundation
import Observation

@MainActor
@Observable
final class GenreBrowseViewModel {
    var movieGenres: [OverseerrGenreSliderItem] = []
    var tvGenres: [OverseerrGenreSliderItem] = []
    var isLoading = false
    var errorMessage: String?

    // Genre results
    var genreResults: [MediaItem] = []
    var isLoadingResults = false
    var resultsErrorMessage: String?
    var currentPage = 1
    var totalPages = 1
    var hasMorePages: Bool { currentPage < totalPages }

    func loadGenres(using client: OverseerrClient) async {
        isLoading = true
        errorMessage = nil

        do {
            async let movieTask = client.movieGenreSlider()
            async let tvTask = client.tvGenreSlider()

            let (movies, tv) = try await (movieTask, tvTask)
            movieGenres = movies
            tvGenres = tv
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadGenreResults(
        genreId: Int,
        mediaType: MediaItem.MediaType,
        page: Int = 1,
        using client: OverseerrClient
    ) async {
        isLoadingResults = true
        resultsErrorMessage = nil

        do {
            if page == 1 {
                // Parallel fetch: quality baseline + recent well-reviewed
                let baseline: OverseerrPagedResponse<OverseerrMediaResult>
                let fresh: OverseerrPagedResponse<OverseerrMediaResult>
                switch mediaType {
                case .movie:
                    async let baselineTask = client.discoverMoviesByGenre(
                        genreId: genreId, page: 1,
                        voteAverageGte: 6.5, voteCountGte: 200
                    )
                    async let freshTask = client.discoverMoviesByGenre(
                        genreId: genreId, page: 1,
                        sortBy: "primary_release_date.desc",
                        voteAverageGte: 6.0, voteCountGte: 100
                    )
                    (baseline, fresh) = try await (baselineTask, freshTask)
                case .tv:
                    async let baselineTask = client.discoverTvByGenre(
                        genreId: genreId, page: 1,
                        voteAverageGte: 6.5, voteCountGte: 200
                    )
                    async let freshTask = client.discoverTvByGenre(
                        genreId: genreId, page: 1,
                        sortBy: "first_air_date.desc",
                        voteAverageGte: 6.0, voteCountGte: 100
                    )
                    (baseline, fresh) = try await (baselineTask, freshTask)
                }

                let baselineItems = baseline.results.compactMap { MediaItem.from(result: $0) }
                let freshItems = fresh.results.prefix(8).compactMap { MediaItem.from(result: $0) }
                genreResults = Self.interleave(baseline: baselineItems, fresh: Array(freshItems))
                currentPage = baseline.page
                totalPages = baseline.totalPages
            } else {
                // Subsequent pages: quality baseline only
                let response: OverseerrPagedResponse<OverseerrMediaResult>
                switch mediaType {
                case .movie:
                    response = try await client.discoverMoviesByGenre(
                        genreId: genreId, page: page,
                        voteAverageGte: 6.5, voteCountGte: 200
                    )
                case .tv:
                    response = try await client.discoverTvByGenre(
                        genreId: genreId, page: page,
                        voteAverageGte: 6.5, voteCountGte: 200
                    )
                }

                let items = response.results.compactMap { MediaItem.from(result: $0) }
                genreResults.append(contentsOf: items)
                currentPage = response.page
                totalPages = response.totalPages
            }
        } catch {
            resultsErrorMessage = error.localizedDescription
        }

        isLoadingResults = false
    }

    /// Interleave fresh (recent) picks into the baseline results, weighted toward the top.
    /// Fresh items are inserted at increasing intervals so they cluster near the start
    /// and taper off, avoiding an artificial "block" of new releases.
    static func interleave(baseline: [MediaItem], fresh: [MediaItem]) -> [MediaItem] {
        let baselineIDs = Set(baseline.map(\.id))
        let uniqueFresh = fresh.filter { !baselineIDs.contains($0.id) }
        guard !uniqueFresh.isEmpty else { return baseline }

        // Insertion points: 0, 2, 5, 9, 14, 20, 27, 35 — gaps widen each step
        var result = baseline
        var inserted = 0
        for item in uniqueFresh {
            let index = inserted + (inserted * (inserted + 1)) / 2  // triangular: 0, 2, 5, 9, 14, 20, ...
            let clampedIndex = min(index, result.count)
            result.insert(item, at: clampedIndex)
            inserted += 1
        }
        return result
    }

    func resetResults() {
        genreResults = []
        currentPage = 1
        totalPages = 1
        resultsErrorMessage = nil
    }
}
