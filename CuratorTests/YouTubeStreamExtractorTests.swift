import XCTest
@testable import Curator

final class YouTubeStreamExtractorTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Innertube ANDROID client (Primary Strategy)

    func testInnertubeReturnsHighestResolutionProgressiveURL() async {
        let session = TestFixtures.mockSession()

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.youtubeInnertubeResponseJSON)
        }

        let url = await YouTubeStreamExtractor.streamURL(for: "dQw4w9WgXcQ", session: session)

        XCTAssertNotNil(url)
        // Should pick the 720p format (itag=22) over the 360p format (itag=18)
        XCTAssertTrue(url!.absoluteString.contains("itag=22"))
    }

    func testInnertubeRequestContainsANDROIDClientContext() async {
        let session = TestFixtures.mockSession()
        var capturedBodyData: Data?

        MockURLProtocol.requestHandler = { request in
            if request.url?.path == "/youtubei/v1/player" {
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
            if request.url?.path == "/youtubei/v1/player" {
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

        let url = await YouTubeStreamExtractor.streamURL(for: "abc123", session: session)

        // Should have tried innertube first, then HTML scraping
        XCTAssertTrue(requestPaths.contains("/youtubei/v1/player"))
        XCTAssertTrue(requestPaths.contains("/watch"))
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.host?.contains("manifest.googlevideo.com") == true)
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
