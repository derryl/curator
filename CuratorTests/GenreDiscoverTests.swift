import XCTest
@testable import Curator

final class GenreDiscoverTests: XCTestCase {

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

    // MARK: - Helpers

    /// Build a paged response JSON with N distinct movie results starting from a given ID offset.
    private static func genreResultsJSON(
        count: Int,
        idOffset: Int = 1,
        page: Int = 1,
        totalPages: Int = 5,
        titlePrefix: String = "Movie"
    ) -> Data {
        let results: [[String: Any]] = (0..<count).map { i in
            [
                "id": idOffset + i,
                "mediaType": "movie",
                "title": "\(titlePrefix) \(idOffset + i)",
                "posterPath": "/poster\(idOffset + i).jpg",
                "overview": "Overview for \(titlePrefix) \(idOffset + i)",
                "voteAverage": 7.0 + Double(i) * 0.1,
                "genreIds": [28],
            ] as [String: Any]
        }
        let json: [String: Any] = [
            "page": page,
            "totalPages": totalPages,
            "totalResults": count * totalPages,
            "results": results,
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    /// Build a paged response JSON for TV results.
    private static func genreTvResultsJSON(
        count: Int,
        idOffset: Int = 1,
        page: Int = 1,
        totalPages: Int = 5,
        titlePrefix: String = "Show"
    ) -> Data {
        let results: [[String: Any]] = (0..<count).map { i in
            [
                "id": idOffset + i,
                "mediaType": "tv",
                "name": "\(titlePrefix) \(idOffset + i)",
                "posterPath": "/poster\(idOffset + i).jpg",
                "overview": "Overview for \(titlePrefix) \(idOffset + i)",
                "voteAverage": 7.0 + Double(i) * 0.1,
                "genreIds": [10759],
            ] as [String: Any]
        }
        let json: [String: Any] = [
            "page": page,
            "totalPages": totalPages,
            "totalResults": count * totalPages,
            "results": results,
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - OverseerrClient: Movie genre discover endpoint

    func testDiscoverMoviesByGenreUsesBaseEndpointWithGenreParam() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, Self.genreResultsJSON(count: 2))
        }

        let response = try await client.discoverMoviesByGenre(genreId: 28, page: 1)

        let request = try XCTUnwrap(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Should hit base /discover/movies, NOT /discover/movies/genre/28
        XCTAssertTrue(request.url!.path.hasSuffix("/api/v1/discover/movies"))
        XCTAssertFalse(request.url!.path.contains("/genre/"))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "genre" && $0.value == "28" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "page" && $0.value == "1" }))
        XCTAssertEqual(response.results.count, 2)
    }

    func testDiscoverMoviesByGenreIncludesFiltersWhenProvided() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, Self.genreResultsJSON(count: 1))
        }

        _ = try await client.discoverMoviesByGenre(
            genreId: 28,
            page: 2,
            sortBy: "vote_average.desc",
            voteAverageGte: 6.5,
            voteCountGte: 200
        )

        let request = try XCTUnwrap(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertTrue(queryItems.contains(where: { $0.name == "sortBy" && $0.value == "vote_average.desc" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "voteAverageGte" && $0.value == "6.5" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "voteCountGte" && $0.value == "200" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "page" && $0.value == "2" }))
    }

    func testDiscoverMoviesByGenreOmitsFiltersWhenNil() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, Self.genreResultsJSON(count: 1))
        }

        _ = try await client.discoverMoviesByGenre(genreId: 12, page: 1)

        let request = try XCTUnwrap(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertFalse(queryItems.contains(where: { $0.name == "sortBy" }))
        XCTAssertFalse(queryItems.contains(where: { $0.name == "voteAverageGte" }))
        XCTAssertFalse(queryItems.contains(where: { $0.name == "voteCountGte" }))
    }

    // MARK: - OverseerrClient: TV genre discover endpoint

    func testDiscoverTvByGenreUsesBaseEndpointWithGenreParam() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, Self.genreTvResultsJSON(count: 2))
        }

        let response = try await client.discoverTvByGenre(genreId: 10759, page: 1)

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertTrue(request.url!.path.hasSuffix("/api/v1/discover/tv"))
        XCTAssertFalse(request.url!.path.contains("/genre/"))

        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        XCTAssertTrue(queryItems.contains(where: { $0.name == "genre" && $0.value == "10759" }))
        XCTAssertEqual(response.results.count, 2)
    }

    func testDiscoverTvByGenreIncludesFiltersWhenProvided() async throws {
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, Self.genreTvResultsJSON(count: 1))
        }

        _ = try await client.discoverTvByGenre(
            genreId: 10759,
            sortBy: "first_air_date.desc",
            voteAverageGte: 6.0,
            voteCountGte: 100
        )

        let request = try XCTUnwrap(capturedRequest)
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertTrue(queryItems.contains(where: { $0.name == "sortBy" && $0.value == "first_air_date.desc" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "voteAverageGte" && $0.value == "6.0" }))
        XCTAssertTrue(queryItems.contains(where: { $0.name == "voteCountGte" && $0.value == "100" }))
    }

    // MARK: - GenreBrowseViewModel: Page 1 (dual-fetch + interleave)
    //
    // NOTE: MockURLProtocol.requestHandler runs on CFNetwork's background thread.
    // In @MainActor test methods, closures inherit MainActor isolation. Nested closures
    // like contains(where:) crash at runtime with dispatch_assert_queue_fail.
    // Fix: use URL string matching (no nested closures) inside handler closures.

    @MainActor
    func testPage1FetchesBothBaselineAndFresh() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        let baselineJSON = Self.genreResultsJSON(count: 10, idOffset: 1, titlePrefix: "Baseline")
        let freshJSON = Self.genreResultsJSON(count: 8, idOffset: 101, titlePrefix: "Fresh")

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, url.contains("sortBy=") ? freshJSON : baselineJSON)
        }

        let vm = GenreBrowseViewModel()
        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 1, using: vmClient)

        XCTAssertFalse(vm.isLoadingResults)
        XCTAssertNil(vm.resultsErrorMessage)
        // 10 baseline + 8 fresh (no overlap) = 18 total
        XCTAssertEqual(vm.genreResults.count, 18)

        let titles = vm.genreResults.map(\.title)
        XCTAssertTrue(titles.contains { $0.hasPrefix("Baseline") })
        XCTAssertTrue(titles.contains { $0.hasPrefix("Fresh") })
    }

    @MainActor
    func testPage1DeduplicatesOverlappingResults() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        let baselineJSON = Self.genreResultsJSON(count: 10, idOffset: 1, titlePrefix: "Baseline")
        let freshJSON = Self.genreResultsJSON(count: 8, idOffset: 5, titlePrefix: "Fresh")

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, url.contains("sortBy=") ? freshJSON : baselineJSON)
        }

        let vm = GenreBrowseViewModel()
        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 1, using: vmClient)

        // 6 of the 8 fresh items overlap with baseline (IDs 5-10), so only 2 unique fresh
        // Total: 10 baseline + 2 unique fresh = 12
        XCTAssertEqual(vm.genreResults.count, 12)

        let ids = vm.genreResults.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Results should not contain duplicate IDs")
    }

    @MainActor
    func testPage1FreshItemsAppearNearTop() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        let baselineJSON = Self.genreResultsJSON(count: 20, idOffset: 1, titlePrefix: "Baseline")
        let freshJSON = Self.genreResultsJSON(count: 8, idOffset: 101, titlePrefix: "Fresh")

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, url.contains("sortBy=") ? freshJSON : baselineJSON)
        }

        let vm = GenreBrowseViewModel()
        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 1, using: vmClient)

        let titles = vm.genreResults.map(\.title)

        XCTAssertTrue(titles[0].hasPrefix("Fresh"), "First item should be a fresh pick")

        let midpoint = titles.count / 2
        let freshInFirstHalf = titles[0..<midpoint].filter { $0.hasPrefix("Fresh") }.count
        let freshInSecondHalf = titles[midpoint...].filter { $0.hasPrefix("Fresh") }.count
        XCTAssertGreaterThanOrEqual(freshInFirstHalf, freshInSecondHalf,
            "Fresh items should be weighted toward the top")
    }

    // MARK: - GenreBrowseViewModel: Page 2+ (baseline only)

    @MainActor
    func testPage2AppendsBaselineOnly() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        nonisolated(unsafe) var requestCount = 0

        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            let url = request.url!.absoluteString
            let response = TestFixtures.httpResponse(url: request.url!)

            if url.contains("page=1") {
                let data = url.contains("sortBy=")
                    ? Self.genreResultsJSON(count: 5, idOffset: 101, titlePrefix: "Fresh")
                    : Self.genreResultsJSON(count: 10, idOffset: 1, totalPages: 3, titlePrefix: "Baseline")
                return (response, data)
            } else {
                return (response, Self.genreResultsJSON(count: 10, idOffset: 50, page: 2, totalPages: 3, titlePrefix: "Page2"))
            }
        }

        let vm = GenreBrowseViewModel()

        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 1, using: vmClient)
        let page1Count = vm.genreResults.count
        let page1RequestCount = requestCount
        XCTAssertEqual(page1RequestCount, 2, "Page 1 should make 2 requests (baseline + fresh)")

        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 2, using: vmClient)
        XCTAssertEqual(requestCount, 3, "Page 2 should make only 1 additional request")
        XCTAssertEqual(vm.genreResults.count, page1Count + 10, "Page 2 results should append")
        XCTAssertEqual(vm.currentPage, 2)
        XCTAssertEqual(vm.totalPages, 3)
        XCTAssertTrue(vm.hasMorePages)
    }

    @MainActor
    func testPage2IncludesQualityFilters() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        nonisolated(unsafe) var page2Request: URLRequest?

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            if url.contains("page=2") { page2Request = request }

            let response = TestFixtures.httpResponse(url: request.url!)
            if url.contains("page=1") {
                let data = url.contains("sortBy=")
                    ? Self.genreResultsJSON(count: 3, idOffset: 101, titlePrefix: "Fresh")
                    : Self.genreResultsJSON(count: 5, idOffset: 1, totalPages: 2, titlePrefix: "Baseline")
                return (response, data)
            } else {
                return (response, Self.genreResultsJSON(count: 5, idOffset: 50, page: 2, totalPages: 2, titlePrefix: "Page2"))
            }
        }

        let vm = GenreBrowseViewModel()
        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 1, using: vmClient)
        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 2, using: vmClient)

        let request = try! XCTUnwrap(page2Request)
        let url = request.url!.absoluteString

        XCTAssertTrue(url.contains("voteAverageGte=6.5"))
        XCTAssertTrue(url.contains("voteCountGte=200"))
        XCTAssertFalse(url.contains("sortBy="))
    }

    // MARK: - GenreBrowseViewModel: TV genre

    @MainActor
    func testPage1WorksForTvGenre() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        let baselineJSON = Self.genreTvResultsJSON(count: 5, idOffset: 1, titlePrefix: "Baseline")
        let freshJSON = Self.genreTvResultsJSON(count: 3, idOffset: 101, titlePrefix: "Fresh")

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            XCTAssertTrue(request.url!.path.contains("/discover/tv"))
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, url.contains("sortBy=") ? freshJSON : baselineJSON)
        }

        let vm = GenreBrowseViewModel()
        await vm.loadGenreResults(genreId: 10759, mediaType: .tv, page: 1, using: vmClient)

        XCTAssertEqual(vm.genreResults.count, 8) // 5 baseline + 3 fresh, no overlap
        XCTAssertNil(vm.resultsErrorMessage)
    }

    @MainActor
    func testTvFreshCallUsesTvSortParameter() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        nonisolated(unsafe) var freshRequestURL: String?

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            if url.contains("sortBy=") { freshRequestURL = url }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, Self.genreTvResultsJSON(count: 3, idOffset: url.contains("sortBy=") ? 101 : 1))
        }

        let vm = GenreBrowseViewModel()
        await vm.loadGenreResults(genreId: 10759, mediaType: .tv, page: 1, using: vmClient)

        let url = try! XCTUnwrap(freshRequestURL)
        XCTAssertTrue(url.contains("sortBy=first_air_date.desc"))
    }

    // MARK: - GenreBrowseViewModel: Error handling

    @MainActor
    func testSetsErrorOnServerFailure() async {
        let session = TestFixtures.mockSession()
        let vmClient = OverseerrClient(baseURL: baseURL, apiKey: "test-key", session: session)

        MockURLProtocol.requestHandler = { request in
            let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
            return (response, TestFixtures.errorJSON())
        }

        let vm = GenreBrowseViewModel()
        await vm.loadGenreResults(genreId: 28, mediaType: .movie, page: 1, using: vmClient)

        XCTAssertNotNil(vm.resultsErrorMessage)
        XCTAssertTrue(vm.genreResults.isEmpty)
        XCTAssertFalse(vm.isLoadingResults)
    }

    // MARK: - Interleave logic (unit tests)

    @MainActor
    func testInterleaveWithEmptyFreshReturnsBaseline() {
        let baseline = (1...5).map { makeMediaItem(id: $0, title: "B\($0)") }
        let result = GenreBrowseViewModel.interleave(baseline: baseline, fresh: [])
        XCTAssertEqual(result.map(\.title), baseline.map(\.title))
    }

    @MainActor
    func testInterleaveWithEmptyBaselineReturnsFresh() {
        let fresh = (1...3).map { makeMediaItem(id: $0, title: "F\($0)") }
        let result = GenreBrowseViewModel.interleave(baseline: [], fresh: fresh)
        XCTAssertEqual(result.map(\.title), fresh.map(\.title))
    }

    @MainActor
    func testInterleaveRemovesDuplicatesByID() {
        let baseline = (1...5).map { makeMediaItem(id: $0, title: "B\($0)") }
        let fresh = (3...7).map { makeMediaItem(id: $0, title: "F\($0)") }

        let result = GenreBrowseViewModel.interleave(baseline: baseline, fresh: fresh)

        let ids = result.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Should have no duplicate IDs")
        // 5 baseline + 2 unique fresh (IDs 6, 7)
        XCTAssertEqual(result.count, 7)
    }

    @MainActor
    func testInterleaveFreshWeightedTowardTop() {
        let baseline = (1...30).map { makeMediaItem(id: $0, title: "B\($0)") }
        let fresh = (101...108).map { makeMediaItem(id: $0, title: "F\($0)") }

        let result = GenreBrowseViewModel.interleave(baseline: baseline, fresh: fresh)

        let midpoint = result.count / 2
        let freshInFirstHalf = result[0..<midpoint].filter { $0.title.hasPrefix("F") }.count
        let freshInSecondHalf = result[midpoint...].filter { $0.title.hasPrefix("F") }.count

        XCTAssertGreaterThan(freshInFirstHalf, freshInSecondHalf,
            "Fresh items should cluster toward the top")
    }

    @MainActor
    func testInterleaveFirstItemIsFresh() {
        let baseline = (1...10).map { makeMediaItem(id: $0, title: "B\($0)") }
        let fresh = (101...103).map { makeMediaItem(id: $0, title: "F\($0)") }

        let result = GenreBrowseViewModel.interleave(baseline: baseline, fresh: fresh)
        XCTAssertTrue(result[0].title.hasPrefix("F"), "First item should be a fresh pick")
    }

    @MainActor
    func testInterleaveInsertionGapsWiden() {
        let baseline = (1...40).map { makeMediaItem(id: $0, title: "B\($0)") }
        let fresh = (101...106).map { makeMediaItem(id: $0, title: "F\($0)") }

        let result = GenreBrowseViewModel.interleave(baseline: baseline, fresh: fresh)
        let freshIndices = result.enumerated().compactMap { $0.element.title.hasPrefix("F") ? $0.offset : nil }

        for i in 1..<freshIndices.count {
            let currentGap = freshIndices[i] - freshIndices[i - 1]
            let previousGap = i > 1 ? freshIndices[i - 1] - freshIndices[i - 2] : 0
            if i > 1 {
                XCTAssertGreaterThanOrEqual(currentGap, previousGap,
                    "Gap between fresh items should widen: gap \(i-1)=\(previousGap), gap \(i)=\(currentGap)")
            }
        }
    }

    // MARK: - Test Helpers

    private func makeMediaItem(id: Int, title: String) -> MediaItem {
        MediaItem(
            id: "movie-\(id)",
            tmdbId: id,
            mediaType: .movie,
            title: title,
            year: nil,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 7.0,
            genreIds: [28],
            availability: .none
        )
    }
}
