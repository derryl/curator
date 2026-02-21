import Foundation
import Observation

@Observable
final class AppState {
    var hasCompletedOnboarding: Bool
    var isTraktConnected: Bool
    var isOverseerrConfigured: Bool

    // Overseerr client — nil until configured
    private(set) var overseerrClient: OverseerrClient?

    // Trakt services — nil until connected
    private(set) var traktClient: TraktClient?
    private(set) var traktAuthManager: TraktAuthManager?
    private(set) var mediaResolver: MediaResolver?

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(for: .hasCompletedOnboarding)
        self.isTraktConnected = UserDefaults.standard.bool(for: .traktIsConnected)

        // Restore Overseerr configuration if previously saved
        if let address = UserDefaults.standard.string(for: .overseerrAddress),
           !address.isEmpty,
           let apiKey = KeychainHelper.readString(key: .overseerrAPIKey) {
            let connectionType = UserDefaults.standard.string(for: .overseerrConnectionType) ?? "http"
            let port = UserDefaults.standard.integer(for: .overseerrPort)
            let effectivePort = port > 0 ? port : Constants.Overseerr.defaultPort
            let urlString = "\(connectionType)://\(address):\(effectivePort)"
            if let url = URL(string: urlString) {
                self.overseerrClient = OverseerrClient(baseURL: url, apiKey: apiKey)
                self.isOverseerrConfigured = true
            } else {
                self.isOverseerrConfigured = false
            }
        } else {
            self.isOverseerrConfigured = false
        }

        // Restore Trakt if previously connected
        let traktAuth = TraktAuthManager()
        self.traktAuthManager = traktAuth

        if isTraktConnected {
            self.traktClient = TraktClient(authManager: traktAuth)
            if let overseerrClient {
                self.mediaResolver = MediaResolver(overseerrClient: overseerrClient)
            }
        }
    }

    func configureOverseerr(connectionType: String, address: String, port: Int, apiKey: String) {
        let urlString = "\(connectionType)://\(address):\(port)"
        guard let url = URL(string: urlString) else { return }

        // Save to persistent storage
        UserDefaults.standard.set(connectionType, for: .overseerrConnectionType)
        UserDefaults.standard.set(address, for: .overseerrAddress)
        UserDefaults.standard.set(port, for: .overseerrPort)
        UserDefaults.standard.set("apiKey", for: .overseerrAuthType)
        try? KeychainHelper.save(apiKey, for: .overseerrAPIKey)

        // Update runtime state
        if let existing = overseerrClient {
            Task { await existing.updateConfiguration(baseURL: url, apiKey: apiKey) }
        } else {
            overseerrClient = OverseerrClient(baseURL: url, apiKey: apiKey)
        }
        isOverseerrConfigured = true

        // Update media resolver if Trakt is connected
        if isTraktConnected, let overseerrClient {
            mediaResolver = MediaResolver(overseerrClient: overseerrClient)
        }
    }

    func clearOverseerr() {
        UserDefaults.standard.set(nil as String?, for: .overseerrAddress)
        UserDefaults.standard.set(nil as String?, for: .overseerrConnectionType)
        UserDefaults.standard.set(0, for: .overseerrPort)
        UserDefaults.standard.set(nil as String?, for: .overseerrAuthType)
        KeychainHelper.delete(key: .overseerrAPIKey)

        overseerrClient = nil
        isOverseerrConfigured = false
        mediaResolver = nil
    }

    func connectTrakt() {
        guard let traktAuthManager else { return }
        traktClient = TraktClient(authManager: traktAuthManager)
        isTraktConnected = true
        UserDefaults.standard.set(true, for: .traktIsConnected)

        if let overseerrClient {
            mediaResolver = MediaResolver(overseerrClient: overseerrClient)
        }
    }

    func disconnectTrakt() {
        traktAuthManager?.clearTokens()
        traktClient = nil
        mediaResolver = nil
        isTraktConnected = false
        UserDefaults.standard.set(false, for: .traktIsConnected)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, for: .hasCompletedOnboarding)
    }
}
