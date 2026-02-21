import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SearchViewModel()
    @Binding var path: NavigationPath

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 280), spacing: 40),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                searchField

                if viewModel.isLoading && viewModel.results.isEmpty {
                    LoadingView(message: "Searching...")
                } else if let error = viewModel.errorMessage, viewModel.results.isEmpty {
                    ErrorView(message: error) {
                        viewModel.search(using: appState.overseerrClient)
                    }
                } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    emptyState
                } else {
                    resultsGrid
                }
            }
            .navigationTitle("Search")
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
        }
    }

    private var searchField: some View {
        TextField("Search movies and TV shows...", text: $viewModel.query)
            .padding()
            .onChange(of: viewModel.query) {
                viewModel.search(using: appState.overseerrClient)
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
                        if item.id == viewModel.results.last?.id {
                            viewModel.loadNextPage(using: appState.overseerrClient)
                        }
                    }
                }
            }
            .padding(40)

            if viewModel.isLoading && !viewModel.results.isEmpty {
                ProgressView()
                    .padding()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No results found")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
