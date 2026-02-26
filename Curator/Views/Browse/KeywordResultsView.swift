import SwiftUI

struct KeywordDestination: Hashable {
    let id: Int
    let name: String
    let mediaType: MediaItem.MediaType
}

struct KeywordResultsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = KeywordBrowseViewModel()

    let keywordId: Int
    let keywordName: String
    let mediaType: MediaItem.MediaType

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 280), spacing: 40),
    ]

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.results.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.results.isEmpty {
                ErrorView(message: error) {
                    loadResults(page: 1)
                }
            } else {
                resultsGrid
            }
        }
        .navigationTitle(keywordName)
        .task {
            if viewModel.results.isEmpty {
                loadResults(page: 1)
            }
        }
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 40) {
                ForEach(viewModel.results) { item in
                    NavigationLink(value: item) {
                        MediaCard(item: item)
                    }
                    .buttonStyle(.focusableCard)
                    .onAppear {
                        if item.id == viewModel.results.last?.id && viewModel.hasMorePages {
                            loadResults(page: viewModel.currentPage + 1)
                        }
                    }
                }
            }
            .padding(60)

            if viewModel.isLoading && !viewModel.results.isEmpty {
                ProgressView()
                    .padding()
            }
        }
    }

    private func loadResults(page: Int) {
        guard let client = appState.overseerrClient else { return }
        Task {
            await viewModel.loadResults(
                keywordId: keywordId,
                mediaType: mediaType,
                page: page,
                using: client
            )
        }
    }
}
