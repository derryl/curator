import SwiftUI

struct BackdropHeroView<Actions: View>: View {
    let title: String
    let backdropPath: String?
    let posterPath: String?
    let metadata: [String]
    let genres: String?
    let actions: Actions

    init(
        title: String,
        backdropPath: String?,
        posterPath: String?,
        metadata: [String],
        genres: String?,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.backdropPath = backdropPath
        self.posterPath = posterPath
        self.metadata = metadata
        self.genres = genres
        self.actions = actions()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-width backdrop
            backdropImage

            // Gradient fade into background
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: Color.black.opacity(0.8), location: 0.7),
                    .init(color: Color.black, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Overlay content
            HStack(alignment: .bottom) {
                // Left: poster + title
                HStack(alignment: .bottom, spacing: 30) {
                    // Poster thumbnail
                    if let url = ImageService.posterURL(posterPath, size: .w342) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(2/3, contentMode: .fit)
                            } else {
                                RoundedRectangle(cornerRadius: 12).fill(.quaternary)
                            }
                        }
                        .frame(width: 200, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    }

                    // Title and metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title)
                            .fontWeight(.bold)

                        if !metadata.isEmpty {
                            HStack(spacing: 16) {
                                ForEach(metadata, id: \.self) { item in
                                    Text(item)
                                }
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }

                        if let genres, !genres.isEmpty {
                            Text(genres)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 20)
                }

                Spacer()

                // Right: action buttons
                actions
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 20)
        }
        .frame(height: 500)
        .clipped()
    }

    @ViewBuilder
    private var backdropImage: some View {
        if let url = ImageService.backdropURL(backdropPath, size: .original) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(.quaternary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 500)
            .clipped()
        } else {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 500)
        }
    }
}

// Backward-compatible initializer for call sites without actions (e.g. TVDetailView)
extension BackdropHeroView where Actions == EmptyView {
    init(
        title: String,
        backdropPath: String?,
        posterPath: String?,
        metadata: [String],
        genres: String?
    ) {
        self.init(
            title: title,
            backdropPath: backdropPath,
            posterPath: posterPath,
            metadata: metadata,
            genres: genres,
            actions: { EmptyView() }
        )
    }
}
