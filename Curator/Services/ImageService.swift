import Foundation

enum ImageService {
    static func posterURL(_ path: String?, size: Constants.TMDBImage.Size = .w500) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return Constants.TMDBImage.posterURL(path: path, size: size)
    }

    static func backdropURL(_ path: String?, size: Constants.TMDBImage.Size = .w780) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return Constants.TMDBImage.backdropURL(path: path, size: size)
    }
}
