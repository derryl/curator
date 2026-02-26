import Foundation
import Observation

@MainActor
@Observable
final class KeywordBrowseViewModel {
    var results: [MediaItem] = []
    var isLoading = false
    var errorMessage: String?
    var currentPage = 1
    var totalPages = 1
    var hasMorePages: Bool { currentPage < totalPages }

    func loadResults(
        keywordId: Int,
        mediaType: MediaItem.MediaType,
        page: Int = 1,
        using client: OverseerrClient
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: OverseerrPagedResponse<OverseerrMediaResult>
            switch mediaType {
            case .movie:
                response = try await client.discoverMoviesByKeyword(keywordId: keywordId, page: page)
            case .tv:
                response = try await client.discoverTvByKeyword(keywordId: keywordId, page: page)
            }

            let items = response.results.compactMap { MediaItem.from(result: $0) }
            if page == 1 {
                results = items
            } else {
                results.append(contentsOf: items)
            }
            currentPage = response.page
            totalPages = response.totalPages
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
