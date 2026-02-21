import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                Section("Overseerr") {
                    NavigationLink {
                        OverseerrSetupView()
                    } label: {
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
                    NavigationLink {
                        TraktSetupView()
                    } label: {
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
        }
    }
}
