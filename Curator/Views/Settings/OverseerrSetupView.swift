import SwiftUI

struct OverseerrSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @State private var showSaveConfirmation = false

    var body: some View {
        Form {
            Section("Connection") {
                Picker("Protocol", selection: $viewModel.connectionType) {
                    Text("HTTP").tag("http")
                    Text("HTTPS").tag("https")
                }

                TextField("Server Address", text: $viewModel.address)
                    .textContentType(.URL)
                    .autocorrectionDisabled()

                TextField("Port", text: $viewModel.port)
            }

            Section("Authentication") {
                TextField("API Key", text: $viewModel.apiKey)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task {
                        _ = await viewModel.testConnection()
                    }
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        if viewModel.isTesting {
                            ProgressView()
                        } else if let result = viewModel.testResult {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .failure:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .disabled(viewModel.isTesting)

                if case .failure(let message) = viewModel.testResult {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Save") {
                    Task {
                        let success = await viewModel.testConnection()
                        if success {
                            viewModel.save(to: appState)
                            showSaveConfirmation = true
                        }
                    }
                }
                .disabled(viewModel.isTesting || viewModel.address.isEmpty || viewModel.apiKey.isEmpty)

                if appState.isOverseerrConfigured {
                    Button("Clear Configuration", role: .destructive) {
                        appState.clearOverseerr()
                        viewModel.loadSavedConfig()
                    }
                }
            }
        }
        .navigationTitle("Overseerr Setup")
        .onAppear {
            viewModel.loadSavedConfig()
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            Text("Overseerr connection saved successfully.")
        }
    }
}
