import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var settingsVM = SettingsViewModel()
    @State private var showConnectionError = false

    // Trakt auth state
    @State private var deviceCode: TraktDeviceCode?
    @State private var traktError: String?
    @State private var pollTask: Task<Void, Never>?

    private let totalSteps = 4

    var body: some View {
        ZStack {
            // Subtle background gradient
            LinearGradient(
                colors: [
                    .black,
                    .black.opacity(0.95),
                    Color.accentColor.opacity(0.05),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    overseerrStep
                case 2:
                    traktStep
                default:
                    readyStep
                }

                Spacer()

                // Step indicator dots
                stepIndicator
                    .padding(.bottom, 40)
            }
            .padding(80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            pollTask?.cancel()
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: step == currentStep ? 10 : 8, height: step == currentStep ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "tv")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Welcome to Curator")
                .font(.title)
                .fontWeight(.bold)

            Text("Discover and request movies and TV shows for your media server.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)

            Button("Get Started") {
                withAnimation { currentStep = 1 }
            }
            .padding(.top, 20)
        }
    }

    private var overseerrStep: some View {
        VStack(spacing: 24) {
            Text("Connect to Overseerr")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your Overseerr server details to get started.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                Picker("Protocol", selection: $settingsVM.connectionType) {
                    Text("HTTP").tag("http")
                    Text("HTTPS").tag("https")
                }

                TextField("Server Address (e.g. 192.168.1.100)", text: $settingsVM.address)
                    .autocorrectionDisabled()

                TextField("Port", text: $settingsVM.port)

                TextField("API Key", text: $settingsVM.apiKey)
                    .autocorrectionDisabled()
            }
            .frame(maxWidth: 600)

            HStack(spacing: 20) {
                Button("Test & Continue") {
                    Task {
                        let success = await settingsVM.testConnection()
                        if success {
                            settingsVM.save(to: appState)
                            withAnimation { currentStep = 2 }
                        } else {
                            showConnectionError = true
                        }
                    }
                }
                .disabled(settingsVM.isTesting || settingsVM.address.isEmpty || settingsVM.apiKey.isEmpty)

                if settingsVM.isTesting {
                    ProgressView()
                }
            }

            if case .failure(let message) = settingsVM.testResult {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private var traktStep: some View {
        VStack(spacing: 24) {
            if let deviceCode {
                DeviceCodeView(
                    userCode: deviceCode.userCode,
                    verificationUrl: deviceCode.verificationUrl
                )
            } else {
                Image(systemName: "person.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                Text("Connect Trakt")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Link your Trakt account for personalized recommendations based on your watch history.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)

                HStack(spacing: 20) {
                    Button("Connect Trakt") {
                        startTraktAuth()
                    }

                    Button("Skip") {
                        withAnimation { currentStep = 3 }
                    }
                }

                if let traktError {
                    Text(traktError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    private var readyStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're all set!")
                .font(.title)
                .fontWeight(.bold)

            Text(appState.isTraktConnected
                 ? "Overseerr and Trakt are connected. Personalized recommendations are ready."
                 : "Overseerr is connected. You can add Trakt later in Settings.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)

            Button("Start Exploring") {
                appState.completeOnboarding()
            }
            .padding(.top, 20)
        }
    }

    private func startTraktAuth() {
        guard let authManager = appState.traktAuthManager else { return }
        traktError = nil

        Task {
            do {
                let code = try await authManager.requestDeviceCode()
                deviceCode = code
                startPolling(deviceCode: code.deviceCode, interval: code.interval)
            } catch {
                traktError = error.localizedDescription
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
                    appState.connectTrakt()
                    self.deviceCode = nil
                    withAnimation { currentStep = 3 }
                    return
                } catch TraktAuthError.pendingAuthorization {
                    continue
                } catch TraktAuthError.slowDown {
                    try? await Task.sleep(for: .seconds(interval))
                    continue
                } catch TraktAuthError.expired {
                    self.deviceCode = nil
                    traktError = "Code expired. Please try again."
                    return
                } catch TraktAuthError.denied {
                    self.deviceCode = nil
                    traktError = "Authorization denied."
                    return
                } catch {
                    self.deviceCode = nil
                    traktError = error.localizedDescription
                    return
                }
            }
        }
    }
}
