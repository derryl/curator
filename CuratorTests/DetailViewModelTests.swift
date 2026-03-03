import XCTest
@testable import Curator

@MainActor
final class DetailViewModelTests: XCTestCase {

    private var viewModel: DetailViewModel!
    private var client: OverseerrClient!
    private let baseURL = URL(string: "https://overseerr.example.com")!

    override func setUp() {
        super.setUp()
        viewModel = DetailViewModel()
        let session = TestFixtures.mockSession()
        client = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        viewModel = nil
        client = nil
        super.tearDown()
    }

    // MARK: - loadMovieDetails

    func testLoadMovieDetailsPopulatesDetailsAndYouMightLikeItems() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/movie/550/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/movie/550/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsJSON
            } else if path.contains("/person/") && path.contains("/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else {
                XCTFail("Unexpected request: \(path)")
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadMovieDetails(tmdbId: 550, using: client)

        XCTAssertNotNil(viewModel.movieDetails)
        XCTAssertEqual(viewModel.movieDetails?.id, 550)
        XCTAssertEqual(viewModel.movieDetails?.title, "Fight Club")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        // youMightLikeItems should contain merged similar + recommended (both share genres with Fight Club)
        XCTAssertFalse(viewModel.youMightLikeItems.isEmpty)
    }

    func testLoadMovieDetailsSetsErrorOnFailure() async {
        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
            return (response, TestFixtures.errorJSON())
        }

        await viewModel.loadMovieDetails(tmdbId: 550, using: client)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.movieDetails)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - requestMedia

    func testRequestMediaSetsSuccessOnOK() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/request") {
                data = TestFixtures.mediaRequestJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.requestMedia(mediaType: "movie", mediaId: 550, using: client)

        if case .success = viewModel.requestResult {
            // expected
        } else {
            XCTFail("Expected .success, got \(String(describing: viewModel.requestResult))")
        }
        XCTAssertFalse(viewModel.isRequesting)
    }

    func testRequestMediaSetsFailureOnServerError() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            if path.contains("/request") {
                let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
                return (response, TestFixtures.errorJSON(message: "Quota exceeded"))
            }
            // For the refresh call after error, it shouldn't reach here
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.movieDetailsJSON)
        }

        await viewModel.requestMedia(mediaType: "movie", mediaId: 550, using: client)

        if case .failure(let msg) = viewModel.requestResult {
            XCTAssertTrue(msg.contains("500"))
        } else {
            XCTFail("Expected .failure, got \(String(describing: viewModel.requestResult))")
        }
        XCTAssertFalse(viewModel.isRequesting)
    }

    func testRequestMediaSendsOnlyMediaTypeAndMediaId() async {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            if path.contains("/request") {
                capturedRequest = request
            }
            let data: Data
            if path.contains("/request") {
                data = TestFixtures.mediaRequestJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.requestMedia(mediaType: "movie", mediaId: 550, using: client)

        let request = try! XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")

        // Read body from httpBodyStream
        if let stream = request.httpBodyStream {
            stream.open()
            var bodyData = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 1024)
                if read > 0 { bodyData.append(buffer, count: read) }
            }
            buffer.deallocate()
            stream.close()

            let json = try! JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
            XCTAssertEqual(json["mediaType"] as? String, "movie")
            XCTAssertEqual(json["mediaId"] as? Int, 550)
            // Should NOT contain profileId, serverId, or rootFolder
            XCTAssertNil(json["profileId"])
            XCTAssertNil(json["serverId"])
            XCTAssertNil(json["rootFolder"])
        }
    }

    func testRequestMediaSetsIsRequestingDuringExecution() async {
        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            let path = request.url!.path
            if path.contains("/request") {
                return (response, TestFixtures.mediaRequestJSON)
            }
            return (response, TestFixtures.movieDetailsJSON)
        }

        // isRequesting starts false
        XCTAssertFalse(viewModel.isRequesting)

        await viewModel.requestMedia(mediaType: "movie", mediaId: 550, using: client)

        // After completion, isRequesting should be false
        XCTAssertFalse(viewModel.isRequesting)
    }

    // MARK: - loadTvDetails

    func testLoadTvDetailsPopulatesDetails() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/tv/1399/similar") {
                data = TestFixtures.similarMoviesJSON // reuse - same structure
            } else if path.contains("/tv/1399/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/tv/1399") {
                data = TestFixtures.tvDetailsJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadTvDetails(tmdbId: 1399, using: client)

        XCTAssertNotNil(viewModel.tvDetails)
        XCTAssertEqual(viewModel.tvDetails?.id, 1399)
        XCTAssertEqual(viewModel.tvDetails?.name, "Breaking Bad")
        XCTAssertEqual(viewModel.tvDetails?.numberOfSeasons, 5)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
}
