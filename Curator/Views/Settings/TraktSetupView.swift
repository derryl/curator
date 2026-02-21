import SwiftUI

struct TraktSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var deviceCode: TraktDeviceCode?
    @State private var isPolling = false
    @State private var errorMessage: String?
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            if appState.isTraktConnected {
                connectedView
            } else if let deviceCode {
                DeviceCodeView(
                    userCode: deviceCode.userCode,
                    verificationUrl: deviceCode.verificationUrl
                )
            } else {
                disconnectedView
            }
        }
        .navigationTitle("Trakt")
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Connect your Trakt account to get personalized recommendations based on your watch history.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)

            Button("Connect Trakt") {
                startDeviceCodeFlow()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var connectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Trakt is connected")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Personalized recommendations are active.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Disconnect", role: .destructive) {
                appState.disconnectTrakt()
            }
        }
    }

    private func startDeviceCodeFlow() {
        guard let authManager = appState.traktAuthManager else { return }
        errorMessage = nil

        Task {
            do {
                let code = try await authManager.requestDeviceCode()
                deviceCode = code
                startPolling(deviceCode: code.deviceCode, interval: code.interval)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startPolling(deviceCode: String, interval: Int) {
        guard let authManager = appState.traktAuthManager else { return }

        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }

                do {
                    _ = try await authManager.pollForToken(deviceCode: deviceCode)
                    // Success — update app state
                    appState.connectTrakt()
                    self.deviceCode = nil
                    return
                } catch TraktAuthError.pendingAuthorization {
                    continue
                } catch TraktAuthError.slowDown {
                    try? await Task.sleep(for: .seconds(interval))
                    continue
                } catch TraktAuthError.expired {
                    self.deviceCode = nil
                    errorMessage = "Code expired. Please try again."
                    return
                } catch TraktAuthError.denied {
                    self.deviceCode = nil
                    errorMessage = "Authorization denied."
                    return
                } catch {
                    self.deviceCode = nil
                    errorMessage = error.localizedDescription
                    return
                }
            }
        }
    }
}
