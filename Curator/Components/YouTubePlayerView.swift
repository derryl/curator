import AVKit
import SwiftUI

struct TrailerVideo: Identifiable {
    let id: String
}

struct TrailerSheet: View {
    let videoKey: String
    @State private var streamURL: URL?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let streamURL {
                TrailerPlayerView(url: streamURL)
                    .ignoresSafeArea()
            } else if failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Unable to load trailer")
                }
                .foregroundStyle(.secondary)
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

private enum YouTubeStreamExtractor {
    static func streamURL(for videoID: String) async -> URL? {
        guard let pageURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else { return nil }

        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("CONSENT=PENDING+999", forHTTPHeaderField: "Cookie")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }

        // Strategy 1: Regex for HLS manifest URL (simplest, avoids JSON parsing)
        if let url = extractHLSURL(from: html) {
            return url
        }

        // Strategy 2: Parse full ytInitialPlayerResponse JSON
        if let playerResponse = extractPlayerResponse(from: html),
           let streamingData = playerResponse["streamingData"] as? [String: Any],
           let url = pickBestStream(from: streamingData) {
            return url
        }

        return nil
    }

    // MARK: Strategy 1 – Regex extraction

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

    // MARK: Strategy 2 – JSON parsing

    private static func extractPlayerResponse(from html: String) -> [String: Any]? {
        // Flexible search: find the marker regardless of surrounding whitespace
        guard let markerRange = html.range(of: "ytInitialPlayerResponse") else { return nil }

        // Find the first `{` after the marker (skips `= ` or `=` or ` = `)
        let afterMarker = html[markerRange.upperBound...]
        guard let braceRange = afterMarker.range(of: "{") else { return nil }
        let jsonStart = braceRange.lowerBound
        let remaining = html[jsonStart...]

        // Find the end of the JSON statement (whichever terminator comes first)
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
                .filter { $0["url"] != nil }
                .max { ($0["height"] as? Int ?? 0) < ($1["height"] as? Int ?? 0) }
            if let urlStr = best?["url"] as? String {
                return URL(string: urlStr)
            }
        }

        return nil
    }
}
