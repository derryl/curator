import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    #if DEBUG
    var connectionType = "http"
    var address = "REDACTED_IP"
    var port = "30002"
    var apiKey = "REDACTED_OVERSEERR_API_KEY"
    #else
    var connectionType = "http"
    var address = ""
    var port = "5055"
    var apiKey = ""
    #endif

    var isTesting = false
    var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

    func loadSavedConfig() {
        connectionType = UserDefaults.standard.string(for: .overseerrConnectionType) ?? "http"
        address = UserDefaults.standard.string(for: .overseerrAddress) ?? ""
        let savedPort = UserDefaults.standard.integer(for: .overseerrPort)
        port = savedPort > 0 ? String(savedPort) : "5055"
        apiKey = KeychainHelper.readString(key: .overseerrAPIKey) ?? ""
    }

    func testConnection() async -> Bool {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        guard !address.isEmpty else {
            testResult = .failure("Server address is required")
            return false
        }
        guard !apiKey.isEmpty else {
            testResult = .failure("API key is required")
            return false
        }

        let portInt = Int(port) ?? Constants.Overseerr.defaultPort
        let urlString = "\(connectionType)://\(address):\(portInt)"
        guard let url = URL(string: urlString) else {
            testResult = .failure("Invalid URL")
            return false
        }

        let client = OverseerrClient(baseURL: url, apiKey: apiKey)
        do {
            _ = try await client.testConnection()
            testResult = .success
            return true
        } catch {
            testResult = .failure(error.localizedDescription)
            return false
        }
    }

    func save(to appState: AppState) {
        let portInt = Int(port) ?? Constants.Overseerr.defaultPort
        appState.configureOverseerr(
            connectionType: connectionType,
            address: address,
            port: portInt,
            apiKey: apiKey
        )
    }
}
