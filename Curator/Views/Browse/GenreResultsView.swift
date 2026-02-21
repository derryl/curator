import SwiftUI

struct GenreResultsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = GenreBrowseViewModel()

    let genreId: Int
    let genreName: String
    let mediaType: MediaItem.MediaType

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 280), spacing: 40),
    ]

    var body: some View {
        Group {
            if viewModel.isLoadingResults && viewModel.genreResults.isEmpty {
                LoadingView()
            } else if let error = viewModel.resultsErrorMessage, viewModel.genreResults.isEmpty {
                ErrorView(message: error) {
                    loadResults(page: 1)
                }
            } else {
                resultsGrid
            }
        }
        .navigationTitle(genreName)
        .task {
            if viewModel.genreResults.isEmpty {
                loadResults(page: 1)
            }
        }
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 40) {
                ForEach(viewModel.genreResults) { item in
                    NavigationLink(value: item) {
                        MediaCard(item: item)
                    }
                    .buttonStyle(.card)
                    .onAppear {
                        if item.id == viewModel.genreResults.last?.id && viewModel.hasMorePages {
                            loadResults(page: viewModel.currentPage + 1)
                        }
                    }
                }
            }
            .padding(60)

            if viewModel.isLoadingResults && !viewModel.genreResults.isEmpty {
                ProgressView()
                    .padding()
            }
        }
    }

    private func loadResults(page: Int) {
        guard let client = appState.overseerrClient else { return }
        Task {
            await viewModel.loadGenreResults(
                genreId: genreId,
                mediaType: mediaType,
                page: page,
                using: client
            )
        }
    }
}
