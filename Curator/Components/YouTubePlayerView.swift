#if canImport(UIKit)
import UIKit
#endif

enum TrailerPlayer {
    static func openExternally(videoKey: String) {
        let youtubeAppURL = URL(string: "youtube://watch/\(videoKey)")!
        let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoKey)")!
        #if canImport(UIKit)
        if UIApplication.shared.canOpenURL(youtubeAppURL) {
            UIApplication.shared.open(youtubeAppURL)
        } else {
            UIApplication.shared.open(webURL)
        }
        #endif
    }
}
