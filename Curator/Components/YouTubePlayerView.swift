import AVKit
import SwiftUI

// MARK: - Stream Result

struct StreamResult: Sendable {
    let videoURL: URL
    let audioURL: URL? // nil for combined progressive streams
    let qualityLabel: String // e.g. "1080p", "720p", "HLS"
}

// MARK: - Trailer Error

enum TrailerError: Error, Sendable {
    case ageRestricted
    case videoUnavailable(reason: String)
    case allStreamsBroken
    case networkError
    case compositionFailed
    case playbackTimeout

    var userMessage: String {
        switch self {
        case .ageRestricted:
            return "This trailer is age-restricted and cannot be played in-app."
        case .videoUnavailable(let reason):
            return "Trailer unavailable: \(reason)"
        case .allStreamsBroken:
            return "Could not load trailer — all stream URLs were inaccessible."
        case .networkError:
            return "Network error — check your connection and try again."
        case .compositionFailed:
            return "Failed to prepare trailer for playback."
        case .playbackTimeout:
            return "Trailer took too long to start. The stream may be temporarily unavailable."
        }
    }
}

// MARK: - Trailer Player

@Observable
@MainActor
final class TrailerPlayer {
    var isLoading = false
    var error: TrailerError?

    private var activePlayerVC: AVPlayerViewController?
    private var activePlayer: AVPlayer?

    func play(videoKey: String) {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            do {
                let result = try await YouTubeStreamExtractor.extractStream(for: videoKey)

                let playerItem: AVPlayerItem
                if let audioURL = result.audioURL {
                    playerItem = try await Self.composePlayerItem(
                        videoURL: result.videoURL, audioURL: audioURL
                    )
                } else {
                    playerItem = AVPlayerItem(url: result.videoURL)
                }

                isLoading = false
                presentPlayer(playerItem: playerItem, videoKey: videoKey)
            } catch let trailerError as TrailerError {
                isLoading = false
                error = trailerError
            } catch {
                isLoading = false
                self.error = .networkError
            }
        }
    }

    func dismissError() {
        error = nil
    }

    // MARK: UIKit Presentation

    private func presentPlayer(playerItem: AVPlayerItem, videoKey: String) {
        let player = AVPlayer(playerItem: playerItem)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.modalPresentationStyle = .fullScreen
        playerVC.allowsPictureInPicturePlayback = false

        // Prevent Dolby Vision / HDR output mode switch for SDR YouTube trailers.
        // Without this, tvOS auto-switches the display from DV to SDR on play and
        // back on dismiss, causing a ~1-2s black screen flash while the TV re-syncs.
        // YouTube trailers are always SDR, so mode switching is never beneficial.
        playerVC.appliesPreferredDisplayCriteriaAutomatically = false

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }

        activePlayer = player
        activePlayerVC = playerVC

        topVC.present(playerVC, animated: true) {
            player.play()
        }

        Task { await monitorPlayback(player: player, playerVC: playerVC) }
    }

    private func monitorPlayback(player: AVPlayer, playerVC: AVPlayerViewController) async {
        // Use structured polling with a shorter total timeout (10s) and check for
        // the specific failure condition vs. legitimate buffering
        let maxAttempts = 20 // 10 seconds total
        for attempt in 0..<maxAttempts {
            try? await Task.sleep(for: .milliseconds(500))

            // Player was dismissed by user — stop monitoring
            guard playerVC.presentingViewController != nil else {
                cleanup()
                return
            }

            // Hard failure from AVPlayer
            if let error = player.currentItem?.error {
                let nsError = error as NSError
                let reason = nsError.localizedFailureReason ?? nsError.localizedDescription
                playerVC.dismiss(animated: true)
                cleanup()
                self.error = .videoUnavailable(reason: reason)
                return
            }

            // Successfully playing — stop monitoring
            if player.timeControlStatus == .playing {
                cleanup()
                return
            }

            // If the player item loaded successfully and is just buffering, give it more time
            if player.currentItem?.status == .readyToPlay && attempt < maxAttempts - 1 {
                continue
            }
        }

        // Timeout — only dismiss if still not playing
        guard playerVC.presentingViewController != nil,
              player.timeControlStatus != .playing else {
            cleanup()
            return
        }
        playerVC.dismiss(animated: true)
        cleanup()
        error = .playbackTimeout
    }

    private func cleanup() {
        activePlayer = nil
        activePlayerVC = nil
    }

    // MARK: Composition

    private static func composePlayerItem(videoURL: URL, audioURL: URL) async throws -> AVPlayerItem {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let videoTracks = try await videoAsset.load(.tracks)
        let audioTracks = try await audioAsset.load(.tracks)
        let videoDuration = try await videoAsset.load(.duration)

        guard let videoTrack = videoTracks.first(where: { $0.mediaType == .video }) else {
            throw TrailerError.compositionFailed
        }

        let composition = AVMutableComposition()

        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compositionVideoTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoTrack,
            at: .zero
        )

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

    // MARK: - Public API

    /// Extracts the best playable stream for a YouTube video.
    /// Throws `TrailerError` with a specific reason on failure.
    static func extractStream(
        for videoID: String,
        session: URLSession = .shared
    ) async throws -> StreamResult {
        // Strategy 1: Innertube ANDROID client (best quality, most formats)
        let androidResult = await extractViaInnertube(
            videoID: videoID,
            clientBody: Self.androidClientBody,
            headers: ["User-Agent": Self.androidUserAgent],
            session: session
        )
        switch androidResult {
        case .success(let result): return result
        case .failure: break // try embedded/HTML next
        }

        // Strategy 2: Innertube embedded player (works for age-restricted embeddable videos)
        let embeddedResult = await extractViaInnertube(
            videoID: videoID,
            clientBody: Self.embeddedClientBody,
            headers: [:],
            session: session
        )
        switch embeddedResult {
        case .success(let result): return result
        case .failure: break
        }

        // Strategy 3: HTML scraping (last resort)
        if let result = await extractViaHTMLScraping(videoID: videoID, session: session) {
            return result
        }

        // Determine the best error to surface
        if case .failure(let error) = androidResult {
            throw error
        }
        if case .failure(let error) = embeddedResult {
            throw error
        }
        throw TrailerError.allStreamsBroken
    }

    /// Legacy convenience that returns a single URL.
    static func streamURL(for videoID: String, session: URLSession = .shared) async -> URL? {
        try? await extractStream(for: videoID, session: session).videoURL
    }

    // MARK: - Client Configurations

    nonisolated(unsafe) static let androidClientBody: [String: Any] = [
        "context": [
            "client": [
                "clientName": "ANDROID",
                "clientVersion": "19.09.37",
                "androidSdkVersion": 34,
                "hl": "en",
                "gl": "US",
            ] as [String: Any],
        ] as [String: Any],
    ]

    static let androidUserAgent = "com.google.android.youtube/19.09.37 (Linux; U; Android 14) gzip"

    nonisolated(unsafe) static let embeddedClientBody: [String: Any] = [
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
    ]

    // MARK: - Codec Compatibility

    /// Mime types that tvOS/AVPlayer can decode natively.
    /// VP9, AV1, and Opus are NOT supported on tvOS.
    static func isTvOSCompatibleVideo(_ mimeType: String) -> Bool {
        let dominated = mimeType.lowercased()
        // H.264 (avc1) and H.265 (hev1/hvc1) in mp4 container
        return dominated.hasPrefix("video/mp4")
    }

    static func isTvOSCompatibleAudio(_ mimeType: String) -> Bool {
        let dominated = mimeType.lowercased()
        // AAC in mp4 container — reject WebM/Opus
        return dominated.hasPrefix("audio/mp4")
    }

    // MARK: – Innertube

    private static func extractViaInnertube(
        videoID: String,
        clientBody: [String: Any],
        headers: [String: String],
        session: URLSession
    ) async -> Result<StreamResult, TrailerError> {
        guard let apiURL = URL(string: "https://www.youtube.com/youtubei/v1/player") else {
            return .failure(.networkError)
        }

        var fullBody = clientBody
        fullBody["videoId"] = videoID
        fullBody["contentCheckOk"] = true

        guard let jsonData = try? JSONSerialization.data(withJSONObject: fullBody) else {
            return .failure(.networkError)
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
            return .failure(.networkError)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(.networkError)
        }

        // Check playability status
        if let playabilityStatus = json["playabilityStatus"] as? [String: Any],
           let status = playabilityStatus["status"] as? String,
           status != "OK" {
            let reason = playabilityStatus["reason"] as? String ?? status
            if status == "LOGIN_REQUIRED" {
                return .failure(.ageRestricted)
            }
            return .failure(.videoUnavailable(reason: reason))
        }

        guard let streamingData = json["streamingData"] as? [String: Any] else {
            return .failure(.allStreamsBroken)
        }

        if let result = await selectStream(from: streamingData, session: session) {
            return .success(result)
        }
        return .failure(.allStreamsBroken)
    }

    // MARK: – HTML Scraping (fallback)

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

        // Sub-strategy A: HLS manifest URL
        if let url = extractHLSURL(from: html) {
            return StreamResult(videoURL: url, audioURL: nil, qualityLabel: "HLS")
        }

        // Sub-strategy B: ytInitialPlayerResponse JSON
        if let playerResponse = extractPlayerResponse(from: html),
           let streamingData = playerResponse["streamingData"] as? [String: Any],
           let result = await selectStream(from: streamingData, session: session) {
            return result
        }

        return nil
    }

    // MARK: – Regex Extraction

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

    // MARK: – JSON Parsing

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

    // MARK: – Stream Selection

    /// Selects the best tvOS-compatible stream with cascading quality fallback.
    /// Validates both video and audio URLs. Falls back through adaptive resolutions
    /// before dropping to progressive formats.
    static func selectStream(
        from streamingData: [String: Any],
        session: URLSession
    ) async -> StreamResult? {
        // Prefer HLS manifest (live streams — AVPlayer handles quality adaptively)
        if let hls = streamingData["hlsManifestUrl"] as? String, let url = URL(string: hls) {
            return StreamResult(videoURL: url, audioURL: nil, qualityLabel: "HLS")
        }

        // Try adaptive formats with cascading quality and codec filtering
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            // Filter to tvOS-compatible codecs only
            let videoFormats = adaptiveFormats.filter {
                $0["url"] is String &&
                isTvOSCompatibleVideo($0["mimeType"] as? String ?? "")
            }
            let audioFormats = adaptiveFormats.filter {
                $0["url"] is String &&
                isTvOSCompatibleAudio($0["mimeType"] as? String ?? "")
            }

            // Sort video by height descending for cascading fallback
            let sortedVideos = videoFormats.sorted {
                ($0["height"] as? Int ?? 0) > ($1["height"] as? Int ?? 0)
            }

            // Best compatible audio (highest bitrate AAC)
            let bestAudio = audioFormats
                .max { ($0["bitrate"] as? Int ?? 0) < ($1["bitrate"] as? Int ?? 0) }

            // Cascade through video resolutions: try 1080p, then 720p, etc.
            for videoFormat in sortedVideos {
                guard let videoURLStr = videoFormat["url"] as? String,
                      let videoURL = URL(string: videoURLStr) else { continue }

                let height = videoFormat["height"] as? Int ?? 0

                // Validate the video URL is accessible
                guard await validateStreamURL(videoURL, session: session) else { continue }

                // If we have a compatible audio stream, validate it too
                if let audioURLStr = bestAudio?["url"] as? String,
                   let audioURL = URL(string: audioURLStr) {
                    if await validateStreamURL(audioURL, session: session) {
                        return StreamResult(
                            videoURL: videoURL,
                            audioURL: audioURL,
                            qualityLabel: "\(height)p"
                        )
                    }
                    // Audio broken — return video-only adaptive (still higher quality than progressive)
                    return StreamResult(
                        videoURL: videoURL,
                        audioURL: nil,
                        qualityLabel: "\(height)p (no audio)"
                    )
                }

                // No compatible audio formats at all — return video-only
                return StreamResult(
                    videoURL: videoURL,
                    audioURL: nil,
                    qualityLabel: "\(height)p (no audio)"
                )
            }
        }

        // Fall back to progressive formats (combined video + audio, max ~720p)
        if let formats = streamingData["formats"] as? [[String: Any]] {
            let compatibleFormats = formats.filter {
                $0["url"] is String &&
                isTvOSCompatibleVideo($0["mimeType"] as? String ?? "")
            }
            let best = compatibleFormats
                .max { ($0["height"] as? Int ?? 0) < ($1["height"] as? Int ?? 0) }
            if let urlStr = best?["url"] as? String, let url = URL(string: urlStr) {
                let height = best?["height"] as? Int ?? 0
                return StreamResult(
                    videoURL: url,
                    audioURL: nil,
                    qualityLabel: "\(height)p"
                )
            }
        }

        return nil
    }

    /// Sends a HEAD request to check if a stream URL is accessible (not 403/blocked).
    static func validateStreamURL(_ url: URL, session: URLSession) async -> Bool {
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
