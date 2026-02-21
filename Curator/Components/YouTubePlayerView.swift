import AVKit
import SwiftUI

struct TrailerVideo: Identifiable {
    let id: String
}

struct StreamResult: Sendable {
    let videoURL: URL
    let audioURL: URL? // nil for combined progressive streams
}

struct TrailerSheet: View {
    let videoKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var playerItem: AVPlayerItem?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let playerItem {
                TrailerPlayerView(playerItem: playerItem)
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
            if let result = await YouTubeStreamExtractor.streamResult(for: videoKey) {
                if let audioURL = result.audioURL {
                    // Adaptive: compose separate video + audio tracks
                    playerItem = await Self.composePlayerItem(videoURL: result.videoURL, audioURL: audioURL)
                } else {
                    // Progressive: single combined URL
                    playerItem = AVPlayerItem(url: result.videoURL)
                }
            } else {
                failed = true
            }
        }
    }

    private static func composePlayerItem(videoURL: URL, audioURL: URL) async -> AVPlayerItem? {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        do {
            let videoTracks = try await videoAsset.load(.tracks)
            let audioTracks = try await audioAsset.load(.tracks)
            let videoDuration = try await videoAsset.load(.duration)

            let composition = AVMutableComposition()

            if let videoTrack = videoTracks.first(where: { $0.mediaType == .video }) {
                let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                try compositionVideoTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoDuration),
                    of: videoTrack,
                    at: .zero
                )
            }

            if let audioTrack = audioTracks.first(where: { $0.mediaType == .audio }) {
                let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                try compositionAudioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoDuration),
                    of: audioTrack,
                    at: .zero
                )
            }

            return AVPlayerItem(asset: composition)
        } catch {
            // Composition failed — fall back to video-only
            return AVPlayerItem(url: videoURL)
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
    let playerItem: AVPlayerItem

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        let player = AVPlayer(playerItem: playerItem)
        vc.player = player
        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}

// MARK: - YouTube Stream Extraction

enum YouTubeStreamExtractor {

    /// Returns a stream result for the given video, preferring highest quality.
    static func streamResult(for videoID: String, session: URLSession = .shared) async -> StreamResult? {
        // Strategy 1: Innertube API with ANDROID client
        if let result = await extractViaInnertubeAndroid(videoID: videoID, session: session) {
            return result
        }

        // Strategy 2 (fallback): HTML scraping
        if let url = await extractViaHTMLScraping(videoID: videoID, session: session) {
            return StreamResult(videoURL: url, audioURL: nil)
        }

        return nil
    }

    /// Legacy convenience that returns a single URL (for tests and simple cases).
    static func streamURL(for videoID: String, session: URLSession = .shared) async -> URL? {
        await streamResult(for: videoID, session: session)?.videoURL
    }

    // MARK: Strategy 1 – Innertube ANDROID client

    private static func extractViaInnertubeAndroid(
        videoID: String,
        session: URLSession
    ) async -> StreamResult? {
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
           let result = pickBestStream(from: streamingData) {
            return result.videoURL
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

    // MARK: – Stream selection

    private static func pickBestStream(from streamingData: [String: Any]) -> StreamResult? {
        // Prefer HLS manifest (live streams)
        if let hls = streamingData["hlsManifestUrl"] as? String, let url = URL(string: hls) {
            return StreamResult(videoURL: url, audioURL: nil)
        }

        // Check adaptive formats for high-quality separate video + audio
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            let videoFormats = adaptiveFormats.filter {
                $0["url"] is String &&
                ($0["mimeType"] as? String)?.hasPrefix("video/") == true
            }
            let audioFormats = adaptiveFormats.filter {
                $0["url"] is String &&
                ($0["mimeType"] as? String)?.hasPrefix("audio/") == true
            }

            let bestVideo = videoFormats
                .max { ($0["height"] as? Int ?? 0) < ($1["height"] as? Int ?? 0) }
            let bestAudio = audioFormats
                .max { ($0["bitrate"] as? Int ?? 0) < ($1["bitrate"] as? Int ?? 0) }

            if let videoURLStr = bestVideo?["url"] as? String,
               let videoURL = URL(string: videoURLStr),
               let audioURLStr = bestAudio?["url"] as? String,
               let audioURL = URL(string: audioURLStr) {
                return StreamResult(videoURL: videoURL, audioURL: audioURL)
            }
        }

        // Fall back to progressive formats (combined video + audio, max ~720p)
        if let formats = streamingData["formats"] as? [[String: Any]] {
            let best = formats
                .filter { $0["url"] is String }
                .max { ($0["height"] as? Int ?? 0) < ($1["height"] as? Int ?? 0) }
            if let urlStr = best?["url"] as? String, let url = URL(string: urlStr) {
                return StreamResult(videoURL: url, audioURL: nil)
            }
        }

        return nil
    }
}
