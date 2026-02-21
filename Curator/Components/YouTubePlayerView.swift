import AVKit
import SwiftUI

struct TrailerVideo: Identifiable {
    let id: String
}

struct TrailerSheet: View {
    let videoKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var streamURL: URL?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let streamURL {
                TrailerPlayerView(url: streamURL)
                    .ignoresSafeArea()
            } else if failed {
                // Extraction failed — dismiss and open externally
                Color.clear
                    .onAppear {
                        openInYouTubeApp()
                        dismiss()
                    }
            } else {
                ProgressView()
            }
        }
        .task {
            if let url = await YouTubeStreamExtractor.streamURL(for: videoKey) {
                streamURL = url
            } else {
                failed = true
            }
        }
    }

    private func openInYouTubeApp() {
        let youtubeAppURL = URL(string: "youtube://watch/\(videoKey)")!
        let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoKey)")!
        let app = UIApplication.shared
        if app.canOpenURL(youtubeAppURL) {
            app.open(youtubeAppURL)
        } else {
            app.open(webURL)
        }
    }
}

private struct TrailerPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        let player = AVPlayer(url: url)
        vc.player = player
        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}

// MARK: - YouTube Stream Extraction

enum YouTubeStreamExtractor {
    static func streamURL(for videoID: String, session: URLSession = .shared) async -> URL? {
        // Strategy 1: Innertube API with ANDROID client (returns progressive MP4)
        if let url = await extractViaInnertubeAndroid(videoID: videoID, session: session) {
            return url
        }

        // Strategy 2 (fallback): HTML scraping
        return await extractViaHTMLScraping(videoID: videoID, session: session)
    }

    // MARK: Strategy 1 – Innertube ANDROID client

    private static func extractViaInnertubeAndroid(
        videoID: String,
        session: URLSession
    ) async -> URL? {
        guard let apiURL = URL(string: "https://www.youtube.com/youtubei/v1/player") else {
            return nil
        }

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "ANDROID",
                    "clientVersion": "19.09.37",
                    "androidSdkVersion": 34,
                    "hl": "en",
                    "gl": "US",
                ] as [String: Any],
            ] as [String: Any],
            "videoId": videoID,
            "contentCheckOk": true,
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "com.google.android.youtube/19.09.37 (Linux; U; Android 14) gzip",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpBody = jsonData

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let streamingData = json["streamingData"] as? [String: Any] else {
            return nil
        }

        return pickBestStream(from: streamingData)
    }

    // MARK: Strategy 2 – HTML scraping (fallback)

    private static func extractViaHTMLScraping(
        videoID: String,
        session: URLSession
    ) async -> URL? {
        guard let pageURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else {
            return nil
        }

        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("CONSENT=PENDING+999", forHTTPHeaderField: "Cookie")

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }

        // Sub-strategy A: Regex for HLS manifest URL
        if let url = extractHLSURL(from: html) {
            return url
        }

        // Sub-strategy B: Parse full ytInitialPlayerResponse JSON
        if let playerResponse = extractPlayerResponse(from: html),
           let streamingData = playerResponse["streamingData"] as? [String: Any],
           let url = pickBestStream(from: streamingData) {
            return url
        }

        return nil
    }

    // MARK: – Regex extraction

    private static func extractHLSURL(from html: String) -> URL? {
        let pattern = #""hlsManifestUrl"\s*:\s*"(https://manifest\.googlevideo\.com/[^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let urlRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let urlString = String(html[urlRange])
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\/", with: "/")

        return URL(string: urlString)
    }

    // MARK: – JSON parsing

    private static func extractPlayerResponse(from html: String) -> [String: Any]? {
        guard let markerRange = html.range(of: "ytInitialPlayerResponse") else { return nil }

        let afterMarker = html[markerRange.upperBound...]
        guard let braceRange = afterMarker.range(of: "{") else { return nil }
        let jsonStart = braceRange.lowerBound
        let remaining = html[jsonStart...]

        var endIndex: String.Index?
        for terminator in [";</script>", ";var ", ";\n"] {
            if let range = remaining.range(of: terminator) {
                if endIndex == nil || range.lowerBound < endIndex! {
                    endIndex = range.lowerBound
                }
            }
        }

        guard let end = endIndex else { return nil }
        let jsonString = String(remaining[..<end])

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }

    private static func pickBestStream(from streamingData: [String: Any]) -> URL? {
        // Prefer HLS manifest
        if let hls = streamingData["hlsManifestUrl"] as? String, let url = URL(string: hls) {
            return url
        }

        // Fall back to progressive formats (combined video + audio)
        if let formats = streamingData["formats"] as? [[String: Any]] {
            let best = formats
                .filter { $0["url"] is String }
                .max { ($0["height"] as? Int ?? 0) < ($1["height"] as? Int ?? 0) }
            if let urlStr = best?["url"] as? String {
                return URL(string: urlStr)
            }
        }

        return nil
    }
}
