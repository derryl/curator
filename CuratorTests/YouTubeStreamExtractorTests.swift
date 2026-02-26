import XCTest
@testable import Curator

final class YouTubeStreamExtractorTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Adaptive Format Selection (Max Quality)

    func testPrefersAdaptiveFormatsOverProgressive() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "dQw4w9WgXcQ", session: session)

        // Should pick 1080p adaptive video (itag=137) over 720p progressive (itag=22)
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=137"))
        // Should have a separate audio URL (itag=140, highest bitrate AAC)
        XCTAssertNotNil(result.audioURL)
        XCTAssertTrue(result.audioURL!.absoluteString.contains("itag=140"))
    }

    func testAdaptiveSelectsHighestResolutionVideo() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // 1080p (itag=137) should be chosen over 720p (itag=136)
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=137"))
    }

    func testAdaptiveSelectsHighestBitrateAudio() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // 128kbps AAC (itag=140) should be chosen over 50kbps Opus (itag=249, filtered out)
        XCTAssertTrue(result.audioURL!.absoluteString.contains("itag=140"))
    }

    func testProgressiveOnlyReturnsNilAudioURL() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeProgressiveOnlyJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // Progressive formats have combined video+audio, so audioURL should be nil
        XCTAssertNil(result.audioURL)
        // Should pick the highest progressive format (720p, itag=22)
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=22"))
    }

    // MARK: - Quality Label

    func testQualityLabelReflectsResolution() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)
        XCTAssertEqual(result.qualityLabel, "1080p")
    }

    // MARK: - Codec Filtering (tvOS Compatibility)

    func testFiltersOutVP9VideoFormats() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeWithVP9JSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // VP9 1440p should be skipped, should pick mp4 720p adaptive instead
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=136"))
        XCTAssertEqual(result.qualityLabel, "720p")
    }

    func testFiltersOutOpusAudioFormats() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeOpusOnlyAudioJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // With only Opus audio (incompatible), should still return video but with nil audio
        XCTAssertNotNil(result.videoURL)
        XCTAssertNil(result.audioURL)
        XCTAssertTrue(result.qualityLabel.contains("no audio"))
    }

    func testCodecFilteringHelpers() {
        // Video: only mp4 containers pass
        XCTAssertTrue(YouTubeStreamExtractor.isTvOSCompatibleVideo("video/mp4; codecs=\"avc1.640028\""))
        XCTAssertTrue(YouTubeStreamExtractor.isTvOSCompatibleVideo("video/mp4; codecs=\"hev1.1.6.L93.B0\""))
        XCTAssertFalse(YouTubeStreamExtractor.isTvOSCompatibleVideo("video/webm; codecs=\"vp9\""))
        XCTAssertFalse(YouTubeStreamExtractor.isTvOSCompatibleVideo("video/webm; codecs=\"av01.0.08M.08\""))

        // Audio: only mp4/AAC passes
        XCTAssertTrue(YouTubeStreamExtractor.isTvOSCompatibleAudio("audio/mp4; codecs=\"mp4a.40.2\""))
        XCTAssertFalse(YouTubeStreamExtractor.isTvOSCompatibleAudio("audio/webm; codecs=\"opus\""))
        XCTAssertFalse(YouTubeStreamExtractor.isTvOSCompatibleAudio("audio/webm; codecs=\"vorbis\""))
    }

    // MARK: - Cascading Quality Fallback

    func testCascadesTo720pWhen1080pURLReturns403() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            // HEAD request to validate adaptive URLs
            if request.httpMethod == "HEAD" {
                let urlStr = request.url!.absoluteString
                if urlStr.contains("itag=137") {
                    // 1080p returns 403
                    let response = TestFixtures.httpResponse(url: request.url!, statusCode: 403)
                    return (response, Data())
                }
                // 720p and audio return 200
                let response = TestFixtures.httpResponse(url: request.url!)
                return (response, Data())
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // Should cascade to 720p (itag=136) after 1080p failed validation
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=136"))
        XCTAssertEqual(result.qualityLabel, "720p")
        // Audio should still be present
        XCTAssertNotNil(result.audioURL)
    }

    func testFallsBackToProgressiveWhenAllAdaptiveURLsReturn403() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "HEAD" {
                let response = TestFixtures.httpResponse(url: request.url!, statusCode: 403)
                return (response, Data())
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // Should fall back to progressive (itag=22, 720p) since all adaptive failed
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=22"))
        XCTAssertNil(result.audioURL)
    }

    // MARK: - Audio URL Validation

    func testReturnsVideoOnlyWhenAudioURLFails() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "HEAD" {
                let urlStr = request.url!.absoluteString
                if urlStr.contains("itag=140") {
                    // Audio URL returns 403
                    let response = TestFixtures.httpResponse(url: request.url!, statusCode: 403)
                    return (response, Data())
                }
                let response = TestFixtures.httpResponse(url: request.url!)
                return (response, Data())
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        // Video should be 1080p but audio should be nil (broken URL)
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=137"))
        XCTAssertNil(result.audioURL)
        XCTAssertTrue(result.qualityLabel.contains("no audio"))
    }

    // MARK: - Error Types

    func testThrowsAgeRestrictedForLoginRequired() async {
        let session = TestFixtures.mockSession()
        var innertubeCallCount = 0

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                innertubeCallCount += 1
                return (response, TestFixtures.youtubeInnertubeLoginRequiredJSON)
            }
            return (response, Data())
        }

        do {
            _ = try await YouTubeStreamExtractor.extractStream(for: "restricted", session: session)
            XCTFail("Expected TrailerError to be thrown")
        } catch let error as TrailerError {
            if case .ageRestricted = error {
                // Expected
            } else {
                XCTFail("Expected .ageRestricted, got \(error)")
            }
        } catch {
            XCTFail("Expected TrailerError, got \(error)")
        }

        // Should have tried both innertube strategies
        XCTAssertEqual(innertubeCallCount, 2)
    }

    func testThrowsVideoUnavailableForErrorStatus() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                return (response, TestFixtures.youtubeInnertubeErrorJSON)
            }
            return (response, Data())
        }

        do {
            _ = try await YouTubeStreamExtractor.extractStream(for: "unavailable", session: session)
            XCTFail("Expected TrailerError to be thrown")
        } catch let error as TrailerError {
            if case .videoUnavailable(let reason) = error {
                XCTAssertTrue(reason.contains("Video unavailable"))
            } else {
                XCTFail("Expected .videoUnavailable, got \(error)")
            }
        } catch {
            XCTFail("Expected TrailerError, got \(error)")
        }
    }

    func testThrowsAllStreamsBrokenWhenNoFormats() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                return (response, TestFixtures.youtubeInnertubeNoFormatsJSON)
            }
            return (response, Data())
        }

        do {
            _ = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)
            XCTFail("Expected TrailerError to be thrown")
        } catch let error as TrailerError {
            if case .allStreamsBroken = error {
                // Expected
            } else {
                XCTFail("Expected .allStreamsBroken, got \(error)")
            }
        } catch {
            XCTFail("Expected TrailerError, got \(error)")
        }
    }

    func testThrowsNetworkErrorWhenAllRequestsFail() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        do {
            _ = try await YouTubeStreamExtractor.extractStream(for: "nonexistent", session: session)
            XCTFail("Expected TrailerError to be thrown")
        } catch {
            // Any error is expected — networkError or allStreamsBroken
            XCTAssertTrue(error is TrailerError)
        }
    }

    // MARK: - Embedded Player Fallback

    func testFallsBackToEmbeddedPlayerWhenAndroidFails() async throws {
        let session = TestFixtures.mockSession()
        var innertubeCallCount = 0

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                innertubeCallCount += 1
                if innertubeCallCount == 1 {
                    return (response, TestFixtures.youtubeInnertubeLoginRequiredJSON)
                } else {
                    return (response, TestFixtures.youtubeInnertubeProgressiveOnlyJSON)
                }
            }
            return (response, Data())
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        XCTAssertNotNil(result)
        XCTAssertEqual(innertubeCallCount, 2)
    }

    // MARK: - Innertube Request Format

    func testInnertubeRequestContainsANDROIDClientContext() async throws {
        let session = TestFixtures.mockSession()
        var capturedBodyData: Data?

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/youtubei/v1/player" && capturedBodyData == nil {
                if let stream = request.httpBodyStream {
                    stream.open()
                    var data = Data()
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                    defer { buffer.deallocate() }
                    while stream.hasBytesAvailable {
                        let read = stream.read(buffer, maxLength: 4096)
                        if read > 0 { data.append(buffer, count: read) }
                        else { break }
                    }
                    stream.close()
                    capturedBodyData = data
                }
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        _ = try await YouTubeStreamExtractor.extractStream(for: "testVideoId", session: session)

        let body = try XCTUnwrap(capturedBodyData)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let context = json["context"] as? [String: Any]
        let client = context?["client"] as? [String: Any]

        XCTAssertEqual(client?["clientName"] as? String, "ANDROID")
        XCTAssertEqual(client?["clientVersion"] as? String, "19.09.37")
        XCTAssertEqual(json["videoId"] as? String, "testVideoId")
    }

    func testInnertubeRequestSendsCorrectUserAgent() async throws {
        let session = TestFixtures.mockSession()
        var capturedUserAgent: String?

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/youtubei/v1/player" && capturedUserAgent == nil {
                capturedUserAgent = request.value(forHTTPHeaderField: "User-Agent")
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        _ = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)

        XCTAssertTrue(capturedUserAgent?.contains("com.google.android.youtube") == true)
    }

    func testInnertubeSkipsFormatsWithoutDirectURL() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                return (response, TestFixtures.youtubeInnertubeNoFormatsJSON)
            }
            return (response, Data())
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "test", session: session)
        XCTAssertNil(url)
    }

    // MARK: - Fallback to HTML Scraping

    func testFallsBackToHTMLScrapingWhenInnertubeFails() async throws {
        let session = TestFixtures.mockSession()
        var requestPaths: [String] = []

        MockURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            requestPaths.append(path)

            if path == "/youtubei/v1/player" {
                let errorResponse = TestFixtures.httpResponse(url: request.url!, statusCode: 403)
                return (errorResponse, Data())
            }

            if path == "/watch" {
                let response = TestFixtures.httpResponse(url: request.url!)
                return (response, TestFixtures.youtubeHTMLWithHLS)
            }

            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, Data())
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "abc123", session: session)

        XCTAssertTrue(requestPaths.contains("/youtubei/v1/player"))
        XCTAssertTrue(requestPaths.contains("/watch"))
        XCTAssertTrue(result.videoURL.host?.contains("manifest.googlevideo.com") == true)
        XCTAssertNil(result.audioURL)
        XCTAssertEqual(result.qualityLabel, "HLS")
    }

    func testFallsBackToHTMLProgressiveFormats() async throws {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/youtubei/v1/player" {
                let errorResponse = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
                return (errorResponse, Data())
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeHTMLWithProgressiveFormats)
        }

        let result = try await YouTubeStreamExtractor.extractStream(for: "test", session: session)
        XCTAssertTrue(result.videoURL.absoluteString.contains("itag=18"))
    }

    // MARK: - Error User Messages

    func testTrailerErrorUserMessages() {
        XCTAssertTrue(TrailerError.ageRestricted.userMessage.contains("age-restricted"))
        XCTAssertTrue(TrailerError.videoUnavailable(reason: "Gone").userMessage.contains("Gone"))
        XCTAssertTrue(TrailerError.allStreamsBroken.userMessage.contains("inaccessible"))
        XCTAssertTrue(TrailerError.networkError.userMessage.contains("Network"))
        XCTAssertTrue(TrailerError.compositionFailed.userMessage.contains("prepare"))
        XCTAssertTrue(TrailerError.playbackTimeout.userMessage.contains("too long"))
    }

    // MARK: - selectStream Direct Tests

    func testSelectStreamPrefersHLSManifest() async {
        let session = TestFixtures.mockSession()
        MockURLProtocol.requestHandler = { request in
            (TestFixtures.httpResponse(url: request.url!), Data())
        }

        let streamingData: [String: Any] = [
            "hlsManifestUrl": "https://manifest.googlevideo.com/api/manifest/hls/test",
            "formats": [
                ["itag": 22, "url": "https://example.com/video", "mimeType": "video/mp4", "height": 720]
            ]
        ]

        let result = await YouTubeStreamExtractor.selectStream(from: streamingData, session: session)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.videoURL.absoluteString.contains("manifest.googlevideo.com"))
        XCTAssertEqual(result!.qualityLabel, "HLS")
    }

    func testSelectStreamReturnsNilForEmptyData() async {
        let session = TestFixtures.mockSession()
        MockURLProtocol.requestHandler = { request in
            (TestFixtures.httpResponse(url: request.url!), Data())
        }

        let result = await YouTubeStreamExtractor.selectStream(from: [:], session: session)
        XCTAssertNil(result)
    }

    // MARK: - Legacy streamURL Convenience

    func testStreamURLReturnsVideoURLFromAdaptiveFormats() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "dQw4w9WgXcQ", session: session)

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("itag=137"))
    }
}
