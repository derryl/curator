import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading && !hasAnyContent {
                    LoadingView(message: "Loading content...")
                } else if let error = viewModel.errorMessage, !hasAnyContent {
                    ErrorView(message: error) {
                        loadContent()
                    }
                } else {
                    contentScrollView
                }
            }
            .navigationDestination(for: MediaItem.self) { item in
                switch item.mediaType {
                case .movie:
                    MovieDetailView(item: item)
                case .tv:
                    TVDetailView(item: item)
                }
            }
            .navigationDestination(for: PersonDestination.self) { person in
                PersonDetailView(person: person)
            }
            .task {
                if !hasAnyContent {
                    loadContent()
                }
            }
        }
    }

    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                // Trakt "Because you watched" shelves
                ForEach(viewModel.recommendationShelves) { shelf in
                    MediaShelfView(title: shelf.title, items: shelf.items)
                }

                if !viewModel.trendingMovies.isEmpty {
                    MediaShelfView(title: "Trending Movies", items: viewModel.trendingMovies)
                }

                if !viewModel.trendingShows.isEmpty {
                    MediaShelfView(title: "Trending Shows", items: viewModel.trendingShows)
                }

                if !viewModel.popularMovies.isEmpty {
                    MediaShelfView(title: "Popular Movies", items: viewModel.popularMovies)
                }

                if !viewModel.popularShows.isEmpty {
                    MediaShelfView(title: "Popular Shows", items: viewModel.popularShows)
                }

                if !viewModel.upcomingMovies.isEmpty {
                    MediaShelfView(title: "Upcoming Movies", items: viewModel.upcomingMovies)
                }

                if !viewModel.upcomingShows.isEmpty {
                    MediaShelfView(title: "Upcoming Shows", items: viewModel.upcomingShows)
                }
            }
            .padding(.vertical, 40)
        }
    }

    private var hasAnyContent: Bool {
        !viewModel.trendingMovies.isEmpty ||
        !viewModel.trendingShows.isEmpty ||
        !viewModel.popularMovies.isEmpty ||
        !viewModel.popularShows.isEmpty ||
        !viewModel.upcomingMovies.isEmpty ||
        !viewModel.upcomingShows.isEmpty ||
        !viewModel.recommendationShelves.isEmpty
    }

    private func loadContent() {
        Task {
            await viewModel.loadContent(
                overseerrClient: appState.overseerrClient,
                traktAuthManager: appState.traktAuthManager,
                traktClient: appState.traktClient,
                mediaResolver: appState.mediaResolver
            )
        }
    }
}
