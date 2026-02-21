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
            let response: OverseerrPagedResponse<OverseerrMediaResult>
            switch mediaType {
            case .movie:
                response = try await client.discoverMoviesByGenre(genreId: genreId, page: page)
            case .tv:
                response = try await client.discoverTvByGenre(genreId: genreId, page: page)
            }

            let items = response.results.compactMap { MediaItem.from(result: $0) }
            if page == 1 {
                genreResults = items
            } else {
                genreResults.append(contentsOf: items)
            }
            currentPage = response.page
            totalPages = response.totalPages
        } catch {
            resultsErrorMessage = error.localizedDescription
        }

        isLoadingResults = false
    }

    func resetResults() {
        genreResults = []
        currentPage = 1
        totalPages = 1
        resultsErrorMessage = nil
    }
}
