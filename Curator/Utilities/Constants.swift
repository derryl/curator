import Foundation

enum Constants {
    // MARK: - Trakt API

    enum Trakt {
        static let baseURL = URL(string: "https://api.trakt.tv")!
        static let apiVersion = "2"
        static let redirectURI = "urn:ietf:wg:oauth:2.0:oob"
        static let clientId = "REDACTED_TRAKT_CLIENT_ID"
        static let clientSecret = "REDACTED_TRAKT_CLIENT_SECRET"
    }

    // MARK: - Overseerr API

    enum Overseerr {
        static let apiPathPrefix = "/api/v1"
        static let defaultPort = 5055
    }

    // MARK: - TMDB Images

    enum TMDBImage {
        static let baseURL = URL(string: "https://image.tmdb.org/t/p/")!

        enum Size: String {
            case w92, w154, w185, w342, w500, w780, original
        }

        static func posterURL(path: String, size: Size = .w500) -> URL {
            baseURL.appendingPathComponent(size.rawValue)
                .appendingPathComponent(path)
        }

        static func backdropURL(path: String, size: Size = .w780) -> URL {
            baseURL.appendingPathComponent(size.rawValue)
                .appendingPathComponent(path)
        }
    }

    // MARK: - Keychain

    enum Keychain {
        static let service = "com.derryl.curator"
    }
}
