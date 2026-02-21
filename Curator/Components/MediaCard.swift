import SwiftUI

struct MediaCard: View {
    let item: MediaItem

    var body: some View {
        Button {
            // Navigation handled by navigationDestination
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                posterImage
                    .overlay(alignment: .topTrailing) {
                        AvailabilityBadge(status: item.availability)
                            .padding(8)
                    }
                    .overlay(alignment: .bottomLeading) {
                        ratingBadge
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        if let year = item.year {
                            Text(String(year))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if item.mediaType == .tv {
                            Text("TV")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.secondary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
            .frame(width: 240)
        }
        .buttonStyle(.card)
    }

    @ViewBuilder
    private var ratingBadge: some View {
        if let rating = item.voteAverage, rating > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                Text(String(format: "%.1f", rating))
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(8)
        }
    }

    @ViewBuilder
    private var posterImage: some View {
        if let url = ImageService.posterURL(item.posterPath) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                case .failure:
                    posterPlaceholder
                default:
                    posterPlaceholder
                        .overlay { ProgressView() }
                }
            }
            .frame(width: 240, height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .frame(width: 240, height: 360)
            .overlay {
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }
}
