import XCTest
@testable import Curator

/// Integration tests that hit real YouTube servers.
/// These verify the extractor works against live videos and catches YouTube API changes.
/// They require a network connection and may be slower than unit tests.
final class YouTubeLiveIntegrationTests: XCTestCase {

    // Well-known public videos unlikely to be removed
    static let stableVideoID = "dQw4w9WgXcQ" // Rick Astley - Never Gonna Give You Up
    static let shortVideoID = "jNQXAC9IVRw"   // "Me at the zoo" — first YouTube video ever
    static let musicVideoID = "kJQP7kiw5Fk"   // Luis Fonsi - Despacito
    static let ageRestrictedID = "6kLq3WMV1nU"  // Age-restricted content

    // MARK: - Stream Extraction (Live)

    func testExtractsStreamFromStableVideo() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.stableVideoID)

        XCTAssertFalse(result.videoURL.absoluteString.isEmpty)
        // Should get a googlevideo.com URL or HLS manifest
        let host = result.videoURL.host ?? ""
        XCTAssertTrue(
            host.contains("googlevideo.com") || host.contains("google.com"),
            "Expected googlevideo.com URL, got: \(result.videoURL)"
        )
    }

    func testExtractsStreamFromShortVideo() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.shortVideoID)

        XCTAssertFalse(result.videoURL.absoluteString.isEmpty)
    }

    func testExtractsStreamFromMusicVideo() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.musicVideoID)

        XCTAssertFalse(result.videoURL.absoluteString.isEmpty)
    }

    // MARK: - Quality Verification (Live)

    func testStableVideoGetsAdaptiveQuality() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.stableVideoID)

        // Popular videos should have adaptive formats available
        // Quality label should indicate resolution (not just "HLS")
        let label = result.qualityLabel
        // Accept any numeric resolution (2160p, 1080p, 720p, etc.) or HLS
        let hasResolution = label.range(of: #"^\d+p"#, options: .regularExpression) != nil
        XCTAssertTrue(
            hasResolution || label == "HLS",
            "Expected a resolution label, got: \(label)"
        )
    }

    func testStableVideoAudioURLIsPresent() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.stableVideoID)

        // If we got adaptive (not HLS), audio should be present
        if result.qualityLabel != "HLS" && !result.qualityLabel.contains("no audio") {
            XCTAssertNotNil(result.audioURL, "Adaptive stream should include audio URL")
        }
    }

    // MARK: - URL Validation (Live)

    func testExtractedVideoURLIsAccessible() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.stableVideoID)

        // The extracted URL should be reachable (not 403/404)
        let isValid = await YouTubeStreamExtractor.validateStreamURL(result.videoURL, session: .shared)
        XCTAssertTrue(isValid, "Extracted video URL should be accessible: \(result.videoURL)")
    }

    func testExtractedAudioURLIsAccessible() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.stableVideoID)

        guard let audioURL = result.audioURL else {
            // HLS or no-audio result — skip this test
            return
        }

        let isValid = await YouTubeStreamExtractor.validateStreamURL(audioURL, session: .shared)
        XCTAssertTrue(isValid, "Extracted audio URL should be accessible: \(audioURL)")
    }

    // MARK: - Error Handling (Live)

    func testNonexistentVideoThrowsError() async {
        do {
            _ = try await YouTubeStreamExtractor.extractStream(for: "ZZZZZZZZZZ_nonexistent")
            XCTFail("Expected error for nonexistent video")
        } catch let error as TrailerError {
            // Should get videoUnavailable or networkError
            switch error {
            case .videoUnavailable, .allStreamsBroken, .networkError:
                break // Expected
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            // Any error is acceptable for a nonexistent video
        }
    }

    func testAgeRestrictedVideoHandledGracefully() async {
        // Age-restricted videos should either extract via embedded player
        // or throw .ageRestricted — they should NOT crash or hang
        do {
            let result = try await YouTubeStreamExtractor.extractStream(for: Self.ageRestrictedID)
            // If extraction succeeds, that's fine (embedded player worked)
            XCTAssertFalse(result.videoURL.absoluteString.isEmpty)
        } catch let error as TrailerError {
            // .ageRestricted is the expected graceful failure
            if case .ageRestricted = error {
                // Expected
            } else if case .videoUnavailable = error {
                // Also acceptable
            } else {
                XCTFail("Age-restricted video should fail with .ageRestricted, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Codec Safety (Live)

    func testExtractedStreamUsesCompatibleCodecs() async throws {
        let result = try await YouTubeStreamExtractor.extractStream(for: Self.stableVideoID)

        let videoURLStr = result.videoURL.absoluteString.lowercased()
        // Should NOT contain VP9 or AV1 indicators in the URL
        // (These would be caught by codec filtering, but verify at the URL level too)
        XCTAssertFalse(videoURLStr.contains("mime=video%2Fwebm"), "Should not select WebM video format")
    }

    // MARK: - Multiple Videos (Batch Reliability)

    func testMultipleVideosExtractSuccessfully() async {
        let videoIDs = [Self.stableVideoID, Self.shortVideoID, Self.musicVideoID]
        var successCount = 0

        for videoID in videoIDs {
            do {
                let result = try await YouTubeStreamExtractor.extractStream(for: videoID)
                if !result.videoURL.absoluteString.isEmpty {
                    successCount += 1
                }
            } catch {
                // Individual failures are OK, but most should succeed
            }
        }

        // At least 2 out of 3 should succeed (accounts for transient failures)
        XCTAssertGreaterThanOrEqual(
            successCount, 2,
            "At least 2 out of 3 stable videos should extract successfully"
        )
    }
}
