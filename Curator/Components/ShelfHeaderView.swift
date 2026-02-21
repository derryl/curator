import SwiftUI

struct ShelfHeaderView: View {
    let title: String
    var seeAllDestination: AnyHashable?
    var onSeeAll: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)

            Spacer()

            if onSeeAll != nil {
                Button("See All") {
                    onSeeAll?()
                }
                .font(.callout)
            }
        }
    }
}
