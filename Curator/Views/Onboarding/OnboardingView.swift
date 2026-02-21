import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep = 0
    @State private var settingsVM = SettingsViewModel()
    @State private var showConnectionError = false

    var body: some View {
        VStack(spacing: 40) {
            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                overseerrStep
            default:
                readyStep
            }
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var readyStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're all set!")
                .font(.title)
                .fontWeight(.bold)

            Text("Overseerr is connected. Start exploring your media library.")
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
}
