import Foundation

enum UserDefaultsKey: String {
    // Overseerr
    case overseerrConnectionType = "overseerr.connectionType"
    case overseerrAddress = "overseerr.address"
    case overseerrPort = "overseerr.port"
    case overseerrAuthType = "overseerr.authType"
    case overseerrUsername = "overseerr.username"

    // Trakt
    case traktIsConnected = "trakt.isConnected"

    // App
    case hasCompletedOnboarding = "app.hasCompletedOnboarding"
}

extension UserDefaults {
    func string(for key: UserDefaultsKey) -> String? {
        string(forKey: key.rawValue)
    }

    func set(_ value: String?, for key: UserDefaultsKey) {
        set(value, forKey: key.rawValue)
    }

    func bool(for key: UserDefaultsKey) -> Bool {
        bool(forKey: key.rawValue)
    }

    func set(_ value: Bool, for key: UserDefaultsKey) {
        set(value, forKey: key.rawValue)
    }

    func integer(for key: UserDefaultsKey) -> Int {
        integer(forKey: key.rawValue)
    }

    func set(_ value: Int, for key: UserDefaultsKey) {
        set(value, forKey: key.rawValue)
    }
}
