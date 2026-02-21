import SwiftUI

struct GenreListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = GenreBrowseViewModel()
    @State private var selectedMediaType = 0
    @Binding var path: NavigationPath

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 40),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading {
                    LoadingView(message: "Loading genres...")
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        loadGenres()
                    }
                } else {
                    genreContent
                }
            }
            .navigationTitle("")
            .navigationDestination(for: GenreDestination.self) { dest in
                GenreResultsView(
                    genreId: dest.id,
                    genreName: dest.name,
                    mediaType: dest.mediaType
                )
            }
            .navigationDestination(for: MediaItem.self) { item in
                switch item.mediaType {
                case .movie:
                    MovieDetailView(item: item)
                case .tv:
                    TVDetailView(item: item)
                }
            }
            .task {
                if viewModel.movieGenres.isEmpty {
                    loadGenres()
                }
            }
        }
    }

    private var genreContent: some View {
        VStack(spacing: 0) {
            Picker("Media Type", selection: $selectedMediaType) {
                Text("Movies").tag(0)
                Text("TV Shows").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 60)
            .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 40) {
                    let genres = selectedMediaType == 0 ? viewModel.movieGenres : viewModel.tvGenres
                    ForEach(genres) { genre in
                        NavigationLink(value: GenreDestination(
                            id: genre.id,
                            name: genre.name,
                            mediaType: selectedMediaType == 0 ? .movie : .tv
                        )) {
                            genreCard(genre, genres: genres)
                        }
                        .buttonStyle(.focusableCard)
                    }
                }
                .padding(60)
            }
        }
    }

    /// Pick a unique backdrop for each genre to avoid repeated images on the grid.
    private func uniqueBackdrop(for genre: OverseerrGenreSliderItem, in genres: [OverseerrGenreSliderItem]) -> String? {
        var usedBackdrops = Set<String>()
        for g in genres {
            guard g.id != genre.id else { break }
            if let first = g.backdrops?.first(where: { !usedBackdrops.contains($0) }) {
                usedBackdrops.insert(first)
            }
        }
        return genre.backdrops?.first(where: { !usedBackdrops.contains($0) })
            ?? genre.backdrops?.first
    }

    private func genreCard(_ genre: OverseerrGenreSliderItem, genres: [OverseerrGenreSliderItem]) -> some View {
        let backdrop = uniqueBackdrop(for: genre, in: genres)
        return ZStack(alignment: .bottomLeading) {
            if let backdrop, let url = ImageService.backdropURL(backdrop) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.quaternary)
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
                    .frame(height: 200)
            }

            Text(genre.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(20)
        }
    }

    private func loadGenres() {
        guard let client = appState.overseerrClient else { return }
        Task {
            await viewModel.loadGenres(using: client)
        }
    }
}

struct GenreDestination: Hashable {
    let id: Int
    let name: String
    let mediaType: MediaItem.MediaType
}
