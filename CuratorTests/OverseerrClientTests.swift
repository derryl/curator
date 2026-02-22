import XCTest
@testable import Curator

final class OverseerrClientTests: XCTestCase {

    private var client: OverseerrClient!
    private let baseURL = URL(string: "https://overseerr.example.com")!
    private let apiKey = "test-api-key"

    override func setUp() {
        super.setUp()
        let session = TestFixtures.mockSession()
        client = OverseerrClient(baseURL: baseURL, apiKey: apiKey, session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        client = nil
        super.tearDown()
    }

    // MARK: - createRequest

    func testCreateRequestSendsCorrectHTTPMethodAndBody() async throws {
        var capturedRequest: URLRequest?
        var capturedBodyData: Data?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            // httpBody is nil in URLProtocol — read from httpBodyStream instead
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
            let response = TestFixtures.httpResponse(url: request.url!, statusCode: 200)
            return (response, TestFixtures.mediaRequestJSON)
        }

        _ = try await client.createRequest(
            mediaType: "movie",
            mediaId: 550,
            serverId: 1,
            profileId: 4,
            rootFolder: "/movies"
        )

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url!.path.contains("/api/v1/request"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), apiKey)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(capturedBodyData)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["mediaType"] as? String, "movie")
        XCTAssertEqual(json["mediaId"] as? Int, 550)
        XCTAssertEqual(json["serverId"] as? Int, 1)
        XCTAssertEqual(json["profileId"] as? Int, 4)
        XCTAssertEqual(json["rootFolder"] as? String, "/movies")
    }

    func testCreateRequestThrowsOnServerError() async {
        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
            return (response, TestFixtures.errorJSON(message: "Internal Server Error"))
        }

        do {
            _ = try await client.createRequest(mediaType: "movie", mediaId: 550)
            XCTFail("Expected error to be thrown")
        } catch let error as OverseerrError {
            if case .httpError(let statusCode, let message) = error {
                XCTAssertEqual(statusCode, 500)
                XCTAssertEqual(message, "Internal Server Error")
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - movieDetails

    func testMovieDetailsDecodesValidResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.path.contains("/api/v1/movie/550"))
            XCTAssertEqual(request.httpMethod, "GET")
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.movieDetailsJSON)
        }

        let details = try await client.movieDetails(tmdbId: 550)
        XCTAssertEqual(details.id, 550)
        XCTAssertEqual(details.title, "Fight Club")
        XCTAssertEqual(details.runtime, 139)
        XCTAssertEqual(details.voteAverage, 8.4)
        XCTAssertEqual(details.genres?.count, 2)
        XCTAssertEqual(details.genres?.first?.name, "Drama")
        XCTAssertEqual(details.credits?.cast?.count, 2)
        XCTAssertEqual(details.credits?.cast?.first?.name, "Edward Norton")
        XCTAssertEqual(details.relatedVideos?.first?.key, "abc123")
    }

    // MARK: - search

    func testSearchSendsCorrectQueryParameters() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.searchResultsJSON)
        }

        let results = try await client.search(query: "Fight Club", page: 1)

        let request = try XCTUnwrap(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertTrue(queryItems.contains(where: { $0.name == "query" && $0.value == "Fight Club" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "page" && $0.value == "1" }))
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(results.results.count, 2)
        XCTAssertEqual(results.totalResults, 2)
    }

    // MARK: - tvDetails

    func testTvDetailsDecodesValidResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.path.contains("/api/v1/tv/1399"))
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.tvDetailsJSON)
        }

        let details = try await client.tvDetails(tmdbId: 1399)
        XCTAssertEqual(details.id, 1399)
        XCTAssertEqual(details.name, "Breaking Bad")
        XCTAssertEqual(details.numberOfSeasons, 5)
        XCTAssertEqual(details.seasons?.count, 2)
        XCTAssertEqual(details.seasons?.first?.episodeCount, 7)
    }

    // MARK: - HTTP Headers

    func testRequestsIncludeAPIKeyHeader() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.movieDetailsJSON)
        }

        _ = try await client.movieDetails(tmdbId: 550)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "test-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }
}
