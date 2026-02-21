import SwiftUI

struct DeviceCodeView: View {
    let userCode: String
    let verificationUrl: String

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "tv.and.mediabox")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Authorize with Trakt")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                Text("Go to")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(verificationUrl)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospaced()

                Text("and enter this code:")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(userCode)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .tracking(8)
                    .padding(.vertical, 12)
            }

            ProgressView()
                .padding(.top, 8)

            Text("Waiting for authorization...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
