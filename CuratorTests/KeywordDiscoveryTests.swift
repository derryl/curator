import XCTest
@testable import Curator

final class KeywordDiscoveryTests: XCTestCase {

    private var client: OverseerrClient!
    private let baseURL = URL(string: "https://overseerr.example.com")!

    override func setUp() {
        super.setUp()
        let session = TestFixtures.mockSession()
        client = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        client = nil
        super.tearDown()
    }

    // MARK: - Keyword decoding in Movie Details

    func testMovieDetailsDecodesKeywords() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.movieDetailsWithKeywordsJSON)
        }

        let details = try await client.movieDetails(tmdbId: 550)
        XCTAssertEqual(details.keywords.count, 3)
        XCTAssertEqual(details.keywords[0].id, 825)
        XCTAssertEqual(details.keywords[0].name, "support group")
        XCTAssertEqual(details.keywords[2].name, "dual identity")
    }

    func testMovieDetailsHandlesMissingKeywords() async throws {
        // movieDetailsJSON has no keywords field
        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.movieDetailsJSON)
        }

        let details = try await client.movieDetails(tmdbId: 550)
        XCTAssertTrue(details.keywords.isEmpty)
    }

    // MARK: - Keyword decoding in TV Details

    func testTvDetailsDecodesKeywords() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.tvDetailsWithKeywordsJSON)
        }

        let details = try await client.tvDetails(tmdbId: 1399)
        // TV uses "results" key inside keywords wrapper
        XCTAssertEqual(details.keywords.count, 2)
        XCTAssertEqual(details.keywords[0].name, "drug dealer")
        XCTAssertEqual(details.keywords[1].name, "cancer")
    }

    func testTvDetailsHandlesMissingKeywords() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.tvDetailsJSON)
        }

        let details = try await client.tvDetails(tmdbId: 1399)
        XCTAssertTrue(details.keywords.isEmpty)
    }

    // MARK: - OverseerrKeyword model

    func testKeywordIsIdentifiable() {
        let keyword = OverseerrKeyword(id: 123, name: "time travel")
        XCTAssertEqual(keyword.id, 123)
        XCTAssertEqual(keyword.name, "time travel")
    }

    func testKeywordIsHashable() {
        let a = OverseerrKeyword(id: 1, name: "heist")
        let b = OverseerrKeyword(id: 1, name: "heist")
        let c = OverseerrKeyword(id: 2, name: "heist")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)

        let set: Set<OverseerrKeyword> = [a, b, c]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - OverseerrKeywordsWrapper

    func testWrapperPrefersKeywordsOverResults() {
        let wrapper = OverseerrKeywordsWrapper(
            keywords: [OverseerrKeyword(id: 1, name: "from keywords")],
            results: [OverseerrKeyword(id: 2, name: "from results")]
        )
        XCTAssertEqual(wrapper.allKeywords.count, 1)
        XCTAssertEqual(wrapper.allKeywords[0].name, "from keywords")
    }

    func testWrapperFallsBackToResults() {
        let wrapper = OverseerrKeywordsWrapper(
            keywords: nil,
            results: [OverseerrKeyword(id: 2, name: "from results")]
        )
        XCTAssertEqual(wrapper.allKeywords.count, 1)
        XCTAssertEqual(wrapper.allKeywords[0].name, "from results")
    }

    func testWrapperReturnsEmptyWhenBothNil() {
        let wrapper = OverseerrKeywordsWrapper(keywords: nil, results: nil)
        XCTAssertTrue(wrapper.allKeywords.isEmpty)
    }

    // MARK: - Keyword discover endpoint

    func testDiscoverMoviesByKeywordSendsCorrectPath() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.keywordDiscoverResultsJSON)
        }

        let response = try await client.discoverMoviesByKeyword(keywordId: 825, page: 2)

        let request = try XCTUnwrap(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertTrue(request.url!.path.contains("/api/v1/discover/movies"))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "withKeywords" && $0.value == "825" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "page" && $0.value == "2" }))
        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.totalPages, 3)
    }

    func testDiscoverTvByKeywordSendsCorrectPath() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.keywordDiscoverResultsJSON)
        }

        _ = try await client.discoverTvByKeyword(keywordId: 310, page: 1)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertTrue(request.url!.path.contains("/api/v1/discover/tv"))
    }

    // MARK: - KeywordBrowseViewModel

    @MainActor
    func testKeywordBrowseViewModelLoadsResults() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.keywordDiscoverResultsJSON)
        }

        let vm = KeywordBrowseViewModel()
        await vm.loadResults(keywordId: 825, mediaType: .movie, page: 1, using: vmClient)

        XCTAssertEqual(vm.results.count, 2)
        XCTAssertEqual(vm.results[0].title, "Keyword Movie A")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.currentPage, 1)
        XCTAssertEqual(vm.totalPages, 3)
        XCTAssertTrue(vm.hasMorePages)
    }

    @MainActor
    func testKeywordBrowseViewModelAppendsOnSubsequentPages() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, TestFixtures.keywordDiscoverResultsJSON)
        }

        let vm = KeywordBrowseViewModel()
        await vm.loadResults(keywordId: 825, mediaType: .movie, page: 1, using: vmClient)
        XCTAssertEqual(vm.results.count, 2)

        // Page 2 should append, not replace
        await vm.loadResults(keywordId: 825, mediaType: .movie, page: 2, using: vmClient)
        XCTAssertEqual(vm.results.count, 4)
    }

    @MainActor
    func testKeywordBrowseViewModelSetsErrorOnFailure() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
            return (response, TestFixtures.errorJSON())
        }

        let vm = KeywordBrowseViewModel()
        await vm.loadResults(keywordId: 825, mediaType: .movie, page: 1, using: vmClient)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - KeywordDestination

    func testKeywordDestinationIsHashable() {
        let a = KeywordDestination(id: 1, name: "heist", mediaType: .movie)
        let b = KeywordDestination(id: 1, name: "heist", mediaType: .movie)
        let c = KeywordDestination(id: 1, name: "heist", mediaType: .tv)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
