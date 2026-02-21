import SwiftUI

struct ShelfHeaderView: View {
    let title: String
    var seeAllDestination: AnyHashable?
    var onSeeAll: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)

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
