import SwiftUI

struct TVDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DetailViewModel()
    @Namespace private var heroFocusScope

    let item: MediaItem
    @State private var showRequestResult = false
    @State private var requestResultMessage = ""
    @State private var trailerPlayer = TrailerPlayer()

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
                    seasonsSection
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
        .overlay {
            if trailerPlayer.isLoading {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        BackdropHeroView(
            title: item.title,
            backdropPath: item.backdropPath,
            posterPath: item.posterPath,
            metadata: heroMetadata,
            genres: viewModel.tvDetails?.genres.map { $0.map(\.name).joined(separator: ", ") }
        ) {
            heroActionButtons
        }
        .focusSection()
    }

    private var heroMetadata: [String] {
        var items: [String] = []
        if let year = item.year {
            items.append(String(year))
        }
        if let seasons = viewModel.tvDetails?.numberOfSeasons {
            items.append("\(seasons) Season\(seasons == 1 ? "" : "s")")
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
                .accessibilityIdentifier("button_trailer")
                .prefersDefaultFocus(in: heroFocusScope)
            }

            Spacer().frame(width: 20)

            let status = viewModel.tvDetails?.mediaInfo?.availabilityStatus ?? item.availability
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
                    .accessibilityIdentifier("button_request_\(profile.id)")
                    .disabled(viewModel.isRequesting)
                }
            }
        }
        .focusScope(heroFocusScope)
    }

    private var trailerKey: String? {
        viewModel.tvDetails?.relatedVideos?
            .first(where: { $0.site == "YouTube" && $0.type == "Trailer" })?
            .key
    }

    private var filteredProfiles: [QualityOption] {
        QualityOption.filtered(from: viewModel.qualityProfiles)
    }

    // MARK: - Content Sections

    @ViewBuilder
    private var availabilityStatus: some View {
        let status = viewModel.tvDetails?.mediaInfo?.availabilityStatus ?? item.availability
        StatusPill(status: status)
    }

    @ViewBuilder
    private var overviewSection: some View {
        if let overview = viewModel.tvDetails?.overview ?? item.overview, !overview.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Overview")
                    .font(.headline)
                    .accessibilityIdentifier("section_overview")
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .focusable()
            }
        }
    }

    @ViewBuilder
    private var seasonsSection: some View {
        if let seasons = viewModel.tvDetails?.seasons, !seasons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Seasons")
                    .font(.headline)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 20) {
                        ForEach(seasons) { season in
                            VStack(spacing: 6) {
                                if let url = ImageService.posterURL(season.posterPath, size: .w185) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(2/3, contentMode: .fill)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                                        }
                                    }
                                    .frame(width: 140, height: 210)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                                        .frame(width: 140, height: 210)
                                }
                                Text(season.name ?? "Season \(season.seasonNumber)")
                                    .font(.caption)
                                    .lineLimit(1)
                                if let count = season.episodeCount {
                                    Text("\(count) episodes")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 150)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .focusSection()
            }
        }
    }

    @ViewBuilder
    private var castSection: some View {
        if let cast = viewModel.tvDetails?.credits?.cast, !cast.isEmpty {
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
            await viewModel.loadTvDetails(tmdbId: item.tmdbId, using: client)
        }
    }

    private func submitRequest(profileId: Int) {
        Task {
            guard let client = appState.overseerrClient else { return }
            await viewModel.requestMedia(
                mediaType: "tv",
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
        trailerPlayer.play(videoKey: key)
    }
}
