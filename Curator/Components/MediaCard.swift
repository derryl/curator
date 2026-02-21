import SwiftUI

struct MediaCard: View {
    let item: MediaItem

    var body: some View {
        posterImage
            .overlay(alignment: .topTrailing) {
                AvailabilityBadge(status: item.availability)
                    .padding(8)
            }
            .overlay(alignment: .bottomTrailing) {
                ratingBadge
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(width: 240)
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
