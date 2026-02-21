import SwiftUI

struct AvailabilityBadge: View {
    let status: MediaItem.AvailabilityStatus

    var body: some View {
        if let config = badgeConfig {
            Image(systemName: config.icon)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(config.color)
                .padding(6)
                .background(config.color.opacity(0.2))
                .clipShape(Circle())
        }
    }

    private var badgeConfig: (icon: String, color: Color)? {
        switch status {
        case .available:
            ("checkmark", .green)
        case .partiallyAvailable:
            ("minus", .green)
        case .processing, .pending:
            ("clock", .yellow)
        case .unknown, .none:
            nil
        }
    }
}
