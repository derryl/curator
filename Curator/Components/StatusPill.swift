import SwiftUI

struct StatusPill: View {
    let status: MediaItem.AvailabilityStatus

    var body: some View {
        if let config = pillConfig {
            Text(config.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(config.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(config.color.opacity(0.2))
                .clipShape(Capsule())
        }
    }

    var testPillConfig: (label: String, color: Color)? { pillConfig }

    private var pillConfig: (label: String, color: Color)? {
        switch status {
        case .available:
            ("Available", .green)
        case .partiallyAvailable:
            ("Partial", .green)
        case .processing:
            ("Processing", .yellow)
        case .pending:
            ("Requested", .yellow)
        case .unknown, .none:
            nil
        }
    }
}
