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

        self.isOverseerrConfigured = false

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
            }
        }

        #if DEBUG
        if !isOverseerrConfigured {
            // Auto-configure from build settings (Secrets.xcconfig -> Info.plist)
            let info = Bundle.main.infoDictionary ?? [:]
            let connType = info["DEBUG_OVERSEERR_CONNECTION_TYPE"] as? String ?? "http"
            let addr = info["DEBUG_OVERSEERR_ADDRESS"] as? String ?? ""
            let port = info["DEBUG_OVERSEERR_PORT"] as? String ?? ""
            let key = info["DEBUG_OVERSEERR_API_KEY"] as? String ?? ""

            if !addr.isEmpty, !key.isEmpty,
               let url = URL(string: "\(connType)://\(addr):\(port)") {
                self.overseerrClient = OverseerrClient(baseURL: url, apiKey: key)
                self.isOverseerrConfigured = true
                self.hasCompletedOnboarding = true
                UserDefaults.standard.set(connType, for: .overseerrConnectionType)
                UserDefaults.standard.set(addr, for: .overseerrAddress)
                UserDefaults.standard.set(Int(port) ?? 5055, for: .overseerrPort)
                try? KeychainHelper.save(key, for: .overseerrAPIKey)
                UserDefaults.standard.set(true, for: .hasCompletedOnboarding)
            }
        }
        #endif

        // Restore Trakt if previously connected
        let traktAuth = TraktAuthManager()
        self.traktAuthManager = traktAuth

        #if DEBUG
        if !traktAuth.isAuthenticated {
            let info = Bundle.main.infoDictionary ?? [:]
            let accessToken = info["DEBUG_TRAKT_ACCESS_TOKEN"] as? String ?? ""
            let refreshToken = info["DEBUG_TRAKT_REFRESH_TOKEN"] as? String ?? ""
            if !accessToken.isEmpty {
                try? KeychainHelper.save(accessToken, for: .traktAccessToken)
                try? KeychainHelper.save(refreshToken, for: .traktRefreshToken)
            }
        }
        #endif

        // Sync isTraktConnected with Keychain state — Keychain persists across
        // reinstalls while UserDefaults does not, so the flag can drift.
        if traktAuth.isAuthenticated && !isTraktConnected {
            self.isTraktConnected = true
            UserDefaults.standard.set(true, for: .traktIsConnected)
        }

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
