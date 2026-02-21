import SwiftUI

struct MovieDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var viewModel = DetailViewModel()

    let item: MediaItem
    @State private var showRequestResult = false
    @State private var requestResultMessage = ""

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    loadDetails()
                }
            } else {
                contentView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .task {
            loadDetails()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                heroSection

                VStack(alignment: .leading, spacing: 40) {
                    availabilityStatus
                    overviewSection
                    castSection
                    youMightLikeSection
                }
                .padding(.horizontal, 60)
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("Request", isPresented: $showRequestResult) {
            Button("OK") {}
        } message: {
            Text(requestResultMessage)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        BackdropHeroView(
            title: item.title,
            backdropPath: item.backdropPath,
            posterPath: item.posterPath,
            metadata: heroMetadata,
            genres: viewModel.movieDetails?.genres.map { $0.map(\.name).joined(separator: ", ") }
        ) {
            heroActionButtons
        }
    }

    private var heroMetadata: [String] {
        var items: [String] = []
        if let year = item.year {
            items.append(String(year))
        }
        if let runtime = viewModel.movieDetails?.runtime {
            items.append("\(runtime) min")
        }
        if let rating = item.voteAverage, rating > 0 {
            items.append("★ \(String(format: "%.1f", rating))")
        }
        return items
    }

    // MARK: - Hero Action Buttons

    @ViewBuilder
    private var heroActionButtons: some View {
        HStack(spacing: 16) {
            if let key = trailerKey {
                Button {
                    openTrailer(key: key)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Trailer")
                    }
                }
            }

            let status = viewModel.movieDetails?.mediaInfo?.availabilityStatus ?? item.availability
            if status == .none || status == .unknown {
                if !filteredProfiles.isEmpty {
                    Text("Request")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredProfiles) { profile in
                    Button {
                        submitRequest(profileId: profile.profileId)
                    } label: {
                        Text(profile.label)
                    }
                    .disabled(viewModel.isRequesting)
                }
            }
        }
    }

    private var trailerKey: String? {
        viewModel.movieDetails?.relatedVideos?.results?
            .first(where: { $0.site == "YouTube" && $0.type == "Trailer" })?
            .key
    }

    private var filteredProfiles: [QualityOption] {
        var fourK: QualityOption?
        var tenEighty: QualityOption?
        for profile in viewModel.qualityProfiles {
            let name = profile.name.lowercased()
            if fourK == nil && (name.contains("4k") || name.contains("2160") || name.contains("uhd")) {
                fourK = QualityOption(id: "4k", profileId: profile.id, label: "4K")
            } else if tenEighty == nil && name.contains("1080") {
                tenEighty = QualityOption(id: "1080", profileId: profile.id, label: "1080p")
            }
        }
        return [tenEighty, fourK].compactMap { $0 }
    }

    // MARK: - Content Sections

    @ViewBuilder
    private var availabilityStatus: some View {
        let status = viewModel.movieDetails?.mediaInfo?.availabilityStatus ?? item.availability
        StatusPill(status: status)
    }

    @ViewBuilder
    private var overviewSection: some View {
        if let overview = viewModel.movieDetails?.overview ?? item.overview, !overview.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Overview")
                    .font(.headline)
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .focusable()
            }
        }
    }

    @ViewBuilder
    private var castSection: some View {
        if let cast = viewModel.movieDetails?.credits?.cast, !cast.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cast")
                    .font(.headline)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 20) {
                        ForEach(cast.prefix(20)) { member in
                            NavigationLink(value: PersonDestination(id: member.id, name: member.name ?? "")) {
                                VStack(spacing: 6) {
                                    if let url = ImageService.posterURL(member.profilePath, size: .w185) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } else {
                                                Circle().fill(.quaternary)
                                            }
                                        }
                                        .frame(width: 140, height: 140)
                                        .clipShape(Circle())
                                    } else {
                                        Circle().fill(.quaternary)
                                            .frame(width: 140, height: 140)
                                            .overlay {
                                                Image(systemName: "person.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                    }
                                    Text(member.name ?? "")
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(member.character ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 160)
                            }
                            .buttonStyle(.focusableCard)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .focusSection()
            }
        }
    }

    @ViewBuilder
    private var youMightLikeSection: some View {
        if !viewModel.youMightLikeItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("You Might Like")
                    .font(.headline)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 30) {
                        ForEach(viewModel.youMightLikeItems) { item in
                            NavigationLink(value: item) {
                                MediaCard(item: item)
                            }
                            .buttonStyle(.focusableCard)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .focusSection()
            }
        }
    }

    // MARK: - Actions

    private func loadDetails() {
        guard let client = appState.overseerrClient else { return }
        Task {
            await viewModel.loadMovieDetails(tmdbId: item.tmdbId, using: client)
        }
    }

    private func submitRequest(profileId: Int) {
        Task {
            guard let client = appState.overseerrClient else { return }
            await viewModel.requestMedia(
                mediaType: "movie",
                mediaId: item.tmdbId,
                profileId: profileId,
                using: client
            )
            if case .success = viewModel.requestResult {
                requestResultMessage = "Request submitted!"
                showRequestResult = true
            } else if case .failure(let msg) = viewModel.requestResult {
                requestResultMessage = msg
                showRequestResult = true
            }
        }
    }

    private func openTrailer(key: String) {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(key)") else { return }
        openURL(url)
    }
}

// MARK: - Quality Option

private struct QualityOption: Identifiable {
    let id: String
    let profileId: Int
    let label: String
}
