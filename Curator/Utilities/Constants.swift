import Foundation

enum Constants {
    // MARK: - Trakt API

    enum Trakt {
        static let baseURL = URL(string: "https://api.trakt.tv")!
        static let apiVersion = "2"
        static let redirectURI = "urn:ietf:wg:oauth:2.0:oob"
        static let clientId = Bundle.main.infoDictionary?["TRAKT_CLIENT_ID"] as? String ?? ""
        static let clientSecret = Bundle.main.infoDictionary?["TRAKT_CLIENT_SECRET"] as? String ?? ""
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

    // MARK: - CouchMoney

    enum CouchMoney {
        static let username = Bundle.main.infoDictionary?["COUCHMONEY_USERNAME"] as? String ?? ""
        static let movieListSlug = "couchmoney-movies"
        static let showListSlug = "couchmoney-shows"
    }

    // MARK: - Keychain

    enum Keychain {
        static let service = "com.derryl.curator"
    }
}
