import SwiftUI

struct MediaShelfView: View {
    let title: String
    let items: [MediaItem]
    var onSeeAll: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeaderView(title: title, onSeeAll: onSeeAll)
                .padding(.horizontal, 60)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 30) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            MediaCard(item: item)
                        }
                        .buttonStyle(.focusableCard)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 20)
            }
            .focusSection()
        }
        .accessibilityIdentifier("media_shelf")
    }
}
