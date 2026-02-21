import SwiftUI

struct FocusableCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(
                color: isFocused ? .white.opacity(0.3) : .clear,
                radius: isFocused ? 20 : 0,
                y: isFocused ? 10 : 0
            )
            .brightness(isFocused ? 0.05 : 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

extension ButtonStyle where Self == FocusableCardButtonStyle {
    static var focusableCard: FocusableCardButtonStyle { FocusableCardButtonStyle() }
}
