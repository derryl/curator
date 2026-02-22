import AVKit
import SwiftUI

struct StreamResult: Sendable {
    let videoURL: URL
    let audioURL: URL? // nil for combined progressive streams
}

// MARK: - Trailer Player

/// Presents trailers by extracting YouTube streams and launching AVPlayerViewController
/// directly via UIKit. This avoids the double-BACK issue caused by wrapping
/// AVPlayerViewController inside SwiftUI's .fullScreenCover.
@Observable
@MainActor
final class TrailerPlayer {
    var isLoading = false

    func play(videoKey: String) {
        guard !isLoading else { return }
        isLoading = true

        Task {
            let result = await YouTubeStreamExtractor.streamResult(for: videoKey)

            guard let result else {
                isLoading = false
                Self.openExternally(videoKey: videoKey)
                return
            }

            let playerItem: AVPlayerItem
            if let audioURL = result.audioURL {
                playerItem = await Self.composePlayerItem(videoURL: result.videoURL, audioURL: audioURL)
                    ?? AVPlayerItem(url: result.videoURL)
            } else {
                playerItem = AVPlayerItem(url: result.videoURL)
            }

            isLoading = false
            presentPlayer(playerItem: playerItem, videoKey: videoKey)
        }
    }

    // MARK: UIKit Presentation

    private func presentPlayer(playerItem: AVPlayerItem, videoKey: String) {
        let player = AVPlayer(playerItem: playerItem)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.modalPresentationStyle = .fullScreen

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }

        topVC.present(playerVC, animated: true) {
            player.play()
        }

        // Monitor for playback errors — dismiss and open externally if the URL is broken
        Task { await monitorPlayback(player: player, playerVC: playerVC, videoKey: videoKey) }
    }

    private func monitorPlayback(player: AVPlayer, playerVC: AVPlayerViewController, videoKey: String) async {
        for _ in 0..<30 { // Poll for up to 15 seconds
            try? await Task.sleep(for: .milliseconds(500))

            // Stop monitoring if the player was already dismissed
            guard playerVC.presentingViewController != nil else { return }

            if player.currentItem?.status == .failed {
                playerVC.dismiss(animated: true) {
                    Self.openExternally(videoKey: videoKey)
                }
                return
            }

            // Player started successfully — stop monitoring
            if player.timeControlStatus == .playing {
                return
            }
        }

        // Timeout: if still not playing after 15 seconds, assume failure
        guard playerVC.presentingViewController != nil else { return }
        if player.timeControlStatus != .playing {
            playerVC.dismiss(animated: true) {
                Self.openExternally(videoKey: videoKey)
            }
        }
    }

    // MARK: Composition

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

    // MARK: External Fallback

    static func openExternally(videoKey: String) {
        let youtubeAppURL = URL(string: "youtube://watch/\(videoKey)")!
        let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoKey)")!
        if UIApplication.shared.canOpenURL(youtubeAppURL) {
            UIApplication.shared.open(youtubeAppURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}

// MARK: - YouTube Stream Extraction

enum YouTubeStreamExtractor {

    /// Returns a stream result for the given video, preferring highest quality.
    /// Validates adaptive URLs before returning them; falls back to progressive if broken.
    static func streamResult(for videoID: String, session: URLSession = .shared) async -> StreamResult? {
        // Strategy 1: Innertube API with ANDROID client
        if let result = await extractViaInnertube(
            videoID: videoID,
            clientBody: [
                "context": [
                    "client": [
                        "clientName": "ANDROID",
                        "clientVersion": "19.09.37",
                        "androidSdkVersion": 34,
                        "hl": "en",
                        "gl": "US",
                    ] as [String: Any],
                ] as [String: Any],
            ],
            headers: [
                "User-Agent": "com.google.android.youtube/19.09.37 (Linux; U; Android 14) gzip",
            ],
            session: session
        ) {
            return result
        }

        // Strategy 2: Innertube embedded player (works for embeddable videos
        // that may require auth with the ANDROID client)
        if let result = await extractViaInnertube(
            videoID: videoID,
            clientBody: [
                "context": [
                    "client": [
                        "clientName": "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
                        "clientVersion": "2.0",
                        "hl": "en",
                        "gl": "US",
                    ] as [String: Any],
                    "thirdParty": [
                        "embedUrl": "https://www.youtube.com/",
                    ] as [String: Any],
                ] as [String: Any],
            ],
            headers: [:],
            session: session
        ) {
            return result
        }

        // Strategy 3 (fallback): HTML scraping
        if let result = await extractViaHTMLScraping(videoID: videoID, session: session) {
            return result
        }

        return nil
    }

    /// Legacy convenience that returns a single URL (for tests and simple cases).
    static func streamURL(for videoID: String, session: URLSession = .shared) async -> URL? {
        await streamResult(for: videoID, session: session)?.videoURL
    }

    // MARK: – Innertube (shared implementation)

    private static func extractViaInnertube(
        videoID: String,
        clientBody: [String: Any],
        headers: [String: String],
        session: URLSession
    ) async -> StreamResult? {
        guard let apiURL = URL(string: "https://www.youtube.com/youtubei/v1/player") else {
            return nil
        }

        var fullBody = clientBody
        fullBody["videoId"] = videoID
        fullBody["contentCheckOk"] = true

        guard let jsonData = try? JSONSerialization.data(withJSONObject: fullBody) else {
            return nil
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = jsonData

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Check playability status — skip if not OK (e.g., LOGIN_REQUIRED, UNPLAYABLE)
        if let playabilityStatus = json["playabilityStatus"] as? [String: Any],
           let status = playabilityStatus["status"] as? String,
           status != "OK" {
            return nil
        }

        guard let streamingData = json["streamingData"] as? [String: Any] else {
            return nil
        }

        return await selectStream(from: streamingData, session: session)
    }

    // MARK: – HTML scraping (fallback)

    private static func extractViaHTMLScraping(
        videoID: String,
        session: URLSession
    ) async -> StreamResult? {
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
            return StreamResult(videoURL: url, audioURL: nil)
        }

        // Sub-strategy B: Parse full ytInitialPlayerResponse JSON
        if let playerResponse = extractPlayerResponse(from: html),
           let streamingData = playerResponse["streamingData"] as? [String: Any],
           let result = await selectStream(from: streamingData, session: session) {
            return result
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

    /// Selects the best stream, validating adaptive URLs before returning them.
    /// Falls back to progressive formats if adaptive URLs are broken (e.g., 403).
    private static func selectStream(from streamingData: [String: Any], session: URLSession) async -> StreamResult? {
        // Prefer HLS manifest (live streams)
        if let hls = streamingData["hlsManifestUrl"] as? String, let url = URL(string: hls) {
            return StreamResult(videoURL: url, audioURL: nil)
        }

        // Try adaptive formats (highest quality, separate video + audio)
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
                // Validate the adaptive video URL is accessible before using it
                if await validateStreamURL(videoURL, session: session) {
                    return StreamResult(videoURL: videoURL, audioURL: audioURL)
                }
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

    /// Sends a HEAD request to check if a stream URL is accessible (not 403/blocked).
    private static func validateStreamURL(_ url: URL, session: URLSession) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        guard let (_, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        return (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 206
    }
}
