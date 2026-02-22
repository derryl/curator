import XCTest
@testable import Curator

final class YouTubeStreamExtractorTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Adaptive Format Selection (Max Quality)

    func testPrefersAdaptiveFormatsOverProgressive() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = await YouTubeStreamExtractor.streamResult(for: "dQw4w9WgXcQ", session: session)

        XCTAssertNotNil(result)
        // Should pick 1080p adaptive video (itag=137) over 720p progressive (itag=22)
        XCTAssertTrue(result!.videoURL.absoluteString.contains("itag=137"))
        // Should have a separate audio URL (itag=140, highest bitrate audio)
        XCTAssertNotNil(result!.audioURL)
        XCTAssertTrue(result!.audioURL!.absoluteString.contains("itag=140"))
    }

    func testAdaptiveSelectsHighestResolutionVideo() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = await YouTubeStreamExtractor.streamResult(for: "test", session: session)

        XCTAssertNotNil(result)
        // 1080p (itag=137) should be chosen over 720p (itag=136)
        XCTAssertTrue(result!.videoURL.absoluteString.contains("itag=137"))
    }

    func testAdaptiveSelectsHighestBitrateAudio() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = await YouTubeStreamExtractor.streamResult(for: "test", session: session)

        XCTAssertNotNil(result)
        // 128kbps (itag=140) should be chosen over 50kbps (itag=249)
        XCTAssertTrue(result!.audioURL!.absoluteString.contains("itag=140"))
    }

    func testProgressiveOnlyReturnsNilAudioURL() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeProgressiveOnlyJSON)
        }

        let result = await YouTubeStreamExtractor.streamResult(for: "test", session: session)

        XCTAssertNotNil(result)
        // Progressive formats have combined video+audio, so audioURL should be nil
        XCTAssertNil(result!.audioURL)
        // Should pick the highest progressive format (720p, itag=22)
        XCTAssertTrue(result!.videoURL.absoluteString.contains("itag=22"))
    }

    // MARK: - Adaptive Validation (403 Fallback)

    func testFallsBackToProgressiveWhenAdaptiveURLReturns403() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            // HEAD request to validate adaptive URL — return 403 (blocked)
            if request.httpMethod == "HEAD" {
                let response = TestFixtures.httpResponse(url: request.url!, statusCode: 403)
                return (response, Data())
            }
            // Innertube response with both adaptive and progressive
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let result = await YouTubeStreamExtractor.streamResult(for: "test", session: session)

        XCTAssertNotNil(result)
        // Should fall back to progressive (itag=22, 720p) since adaptive failed validation
        XCTAssertTrue(result!.videoURL.absoluteString.contains("itag=22"))
        // Progressive has combined audio, so audioURL should be nil
        XCTAssertNil(result!.audioURL)
    }

    // MARK: - Playability Status

    func testRejectsLoginRequiredPlayabilityStatus() async {
        let session = TestFixtures.mockSession()
        var innertubeCallCount = 0

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                innertubeCallCount += 1
                // Both ANDROID and embedded get LOGIN_REQUIRED
                return (response, TestFixtures.youtubeInnertubeLoginRequiredJSON)
            }
            // HTML fallback returns nothing
            return (response, Data())
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "restricted", session: session)

        XCTAssertNil(url)
        // Should have tried both innertube strategies (ANDROID + embedded)
        XCTAssertEqual(innertubeCallCount, 2)
    }

    // MARK: - Embedded Player Fallback

    func testFallsBackToEmbeddedPlayerWhenAndroidFails() async {
        let session = TestFixtures.mockSession()
        var innertubeCallCount = 0

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                innertubeCallCount += 1
                if innertubeCallCount == 1 {
                    // ANDROID client fails with LOGIN_REQUIRED
                    return (response, TestFixtures.youtubeInnertubeLoginRequiredJSON)
                } else {
                    // Embedded player succeeds
                    return (response, TestFixtures.youtubeInnertubeProgressiveOnlyJSON)
                }
            }
            return (response, Data())
        }

        let result = await YouTubeStreamExtractor.streamResult(for: "test", session: session)

        XCTAssertNotNil(result)
        XCTAssertEqual(innertubeCallCount, 2)
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
        // streamURL should return the videoURL from the adaptive result
        XCTAssertTrue(url!.absoluteString.contains("itag=137"))
    }

    // MARK: - Innertube ANDROID Client Request Format

    func testInnertubeRequestContainsANDROIDClientContext() async {
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

        _ = await YouTubeStreamExtractor.streamURL(for: "testVideoId", session: session)

        let body = try! XCTUnwrap(capturedBodyData)
        let json = try! XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let context = json["context"] as? [String: Any]
        let client = context?["client"] as? [String: Any]

        XCTAssertEqual(client?["clientName"] as? String, "ANDROID")
        XCTAssertEqual(client?["clientVersion"] as? String, "19.09.37")
        XCTAssertEqual(json["videoId"] as? String, "testVideoId")
    }

    func testInnertubeRequestSendsCorrectUserAgent() async {
        let session = TestFixtures.mockSession()
        var capturedUserAgent: String?

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/youtubei/v1/player" && capturedUserAgent == nil {
                capturedUserAgent = request.value(forHTTPHeaderField: "User-Agent")
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        _ = await YouTubeStreamExtractor.streamURL(for: "test", session: session)

        XCTAssertTrue(capturedUserAgent?.contains("com.google.android.youtube") == true)
    }

    func testInnertubeSkipsFormatsWithoutDirectURL() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                return (response, TestFixtures.youtubeInnertubeNoFormatsJSON)
            }
            // Fallback HTML also returns nothing useful
            return (response, Data())
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "test", session: session)

        XCTAssertNil(url)
    }

    // MARK: - Fallback to HTML Scraping

    func testFallsBackToHTMLScrapingWhenInnertubeFails() async {
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

        let result = await YouTubeStreamExtractor.streamResult(for: "abc123", session: session)

        // Should have tried both innertube strategies, then HTML scraping
        XCTAssertTrue(requestPaths.contains("/youtubei/v1/player"))
        XCTAssertTrue(requestPaths.contains("/watch"))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.videoURL.host?.contains("manifest.googlevideo.com") == true)
        // HTML fallback returns combined streams, so audioURL should be nil
        XCTAssertNil(result!.audioURL)
    }

    func testFallsBackToHTMLProgressiveFormats() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/youtubei/v1/player" {
                let errorResponse = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
                return (errorResponse, Data())
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeHTMLWithProgressiveFormats)
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "test", session: session)

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("itag=18"))
    }

    // MARK: - Complete Failure

    func testReturnsNilWhenAllStrategiesFail() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
            return (response, Data())
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "nonexistent", session: session)

        XCTAssertNil(url)
    }

    func testReturnsNilForErrorResponse() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            if request.url?.path == "/youtubei/v1/player" {
                return (response, TestFixtures.youtubeInnertubeErrorJSON)
            }
            return (response, Data())
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "unavailable", session: session)

        XCTAssertNil(url)
    }
}
