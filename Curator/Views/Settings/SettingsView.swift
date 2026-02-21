import SwiftUI

enum SettingsDestination: Hashable {
    case overseerr
    case trakt
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Overseerr") {
                    NavigationLink(value: SettingsDestination.overseerr) {
                        HStack {
                            Label("Server", systemImage: "server.rack")
                            Spacer()
                            if appState.isOverseerrConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not configured")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Trakt") {
                    NavigationLink(value: SettingsDestination.trakt) {
                        HStack {
                            Label("Account", systemImage: "person.circle")
                            Spacer()
                            if appState.isTraktConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Not connected")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
                case .overseerr:
                    OverseerrSetupView()
                case .trakt:
                    TraktSetupView()
                }
            }
        }
    }
}
