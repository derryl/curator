import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: [MediaItem] = []
    var isLoading = false
    var errorMessage: String?
    var currentPage = 1
    var totalPages = 1
    var hasMorePages: Bool { currentPage < totalPages }

    private var searchTask: Task<Void, Never>?

    func search(using client: OverseerrClient?) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            currentPage = 1
            totalPages = 1
            return
        }

        guard let client else {
            errorMessage = "Overseerr is not configured"
            return
        }

        searchTask = Task {
            isLoading = true
            errorMessage = nil

            // Debounce
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            do {
                let response = try await client.search(query: trimmed, page: 1)
                guard !Task.isCancelled else { return }
                results = response.results.compactMap { MediaItem.from(result: $0) }
                currentPage = response.page
                totalPages = response.totalPages
            } catch is CancellationError {
                // Ignore
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func loadNextPage(using client: OverseerrClient?) {
        guard hasMorePages, !isLoading, let client else { return }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            isLoading = true
            do {
                let response = try await client.search(query: trimmed, page: currentPage + 1)
                let newItems = response.results.compactMap { MediaItem.from(result: $0) }
                results.append(contentsOf: newItems)
                currentPage = response.page
                totalPages = response.totalPages
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
