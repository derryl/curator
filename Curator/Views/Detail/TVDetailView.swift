import SwiftUI

struct TVDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DetailViewModel()

    let item: MediaItem
    @State private var showRequestConfirmation = false

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
                    actionSection
                    overviewSection
                    seasonsSection
                    castSection
                    similarSection
                    recommendedSection
                }
                .padding(.horizontal, 60)
            }
        }
    }

    private var heroSection: some View {
        BackdropHeroView(
            title: item.title,
            backdropPath: item.backdropPath,
            posterPath: item.posterPath,
            metadata: heroMetadata,
            genres: viewModel.tvDetails?.genres.map { $0.map(\.name).joined(separator: ", ") }
        )
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

    @ViewBuilder
    private var availabilityStatus: some View {
        let status = viewModel.tvDetails?.mediaInfo?.availabilityStatus ?? item.availability
        StatusPill(status: status)
    }

    @ViewBuilder
    private var actionSection: some View {
        let status = viewModel.tvDetails?.mediaInfo?.availabilityStatus ?? item.availability
        if status == .none || status == .unknown {
            if viewModel.qualityProfiles.isEmpty {
                Button {
                    showRequestConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Request")
                    }
                }
                .disabled(viewModel.isRequesting)
                .alert("Request TV Show", isPresented: $showRequestConfirmation) {
                    Button("Request") {
                        submitRequest(profileId: nil)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Request \"\(item.title)\"?")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Request \"\(item.title)\"")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach(viewModel.qualityProfiles) { profile in
                            Button {
                                submitRequest(profileId: profile.id)
                            } label: {
                                Text(profile.name)
                            }
                            .disabled(viewModel.isRequesting)
                        }
                    }
                }
            }
        }

        if case .success = viewModel.requestResult {
            Text("Request submitted!")
                .foregroundStyle(.green)
                .font(.callout)
        } else if case .failure(let msg) = viewModel.requestResult {
            Text(msg)
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    @ViewBuilder
    private var overviewSection: some View {
        if let overview = viewModel.tvDetails?.overview ?? item.overview, !overview.isEmpty {
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
    private var similarSection: some View {
        if !viewModel.similarItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Similar")
                    .font(.headline)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 30) {
                        ForEach(viewModel.similarItems) { similar in
                            NavigationLink(value: similar) {
                                MediaCard(item: similar)
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
    private var recommendedSection: some View {
        if !viewModel.recommendedItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommended")
                    .font(.headline)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 30) {
                        ForEach(viewModel.recommendedItems) { recommended in
                            NavigationLink(value: recommended) {
                                MediaCard(item: recommended)
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

    private func loadDetails() {
        guard let client = appState.overseerrClient else { return }
        Task {
            await viewModel.loadTvDetails(tmdbId: item.tmdbId, using: client)
        }
    }

    private func submitRequest(profileId: Int?) {
        Task {
            guard let client = appState.overseerrClient else { return }
            await viewModel.requestMedia(
                mediaType: "tv",
                mediaId: item.tmdbId,
                profileId: profileId,
                using: client
            )
        }
    }
}
