import XCTest
@testable import Curator

@MainActor
final class PersonShelfTests: XCTestCase {

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

    // MARK: - Director shelf on movies

    func testLoadMovieDetailsPopulatesDirectorShelf() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/person/7467/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else if path.contains("/movie/550/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/movie/550/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsWithCrewJSON
            } else if path.contains("/person/819/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else if path.contains("/service/radarr/") {
                data = TestFixtures.radarrServiceDetailsJSON
            } else if path.contains("/service/radarr") {
                data = TestFixtures.radarrServicesJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadMovieDetails(tmdbId: 550, using: client)

        XCTAssertNotNil(viewModel.directorShelf)
        XCTAssertEqual(viewModel.directorShelf?.name, "David Fincher")
        XCTAssertFalse(viewModel.directorShelf?.items.isEmpty ?? true)
    }

    func testDirectorShelfExcludesCurrentTitle() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/person/") && path.contains("/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else if path.contains("/movie/550/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/movie/550/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsWithCrewJSON
            } else if path.contains("/service/radarr/") {
                data = TestFixtures.radarrServiceDetailsJSON
            } else if path.contains("/service/radarr") {
                data = TestFixtures.radarrServicesJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadMovieDetails(tmdbId: 550, using: client)

        // The person credits fixture includes id 550 (Fight Club) — it should be excluded
        if let items = viewModel.directorShelf?.items {
            XCTAssertFalse(items.contains(where: { $0.tmdbId == 550 }),
                           "Director shelf should not include the current title")
        }
    }

    // MARK: - Lead actor shelf on movies

    func testLoadMovieDetailsPopulatesLeadActorShelf() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/person/") && path.contains("/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else if path.contains("/movie/550/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/movie/550/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsWithCrewJSON
            } else if path.contains("/service/radarr/") {
                data = TestFixtures.radarrServiceDetailsJSON
            } else if path.contains("/service/radarr") {
                data = TestFixtures.radarrServicesJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadMovieDetails(tmdbId: 550, using: client)

        XCTAssertNotNil(viewModel.leadActorShelf)
        XCTAssertEqual(viewModel.leadActorShelf?.name, "Edward Norton")
    }

    // MARK: - TV: Executive Producer shelf

    func testLoadTvDetailsPopulatesProducerShelf() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/person/") && path.contains("/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else if path.contains("/tv/1399/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/tv/1399/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/tv/1399") {
                data = TestFixtures.tvDetailsWithCrewJSON
            } else if path.contains("/service/sonarr/") {
                data = TestFixtures.radarrServiceDetailsJSON
            } else if path.contains("/service/sonarr") {
                data = TestFixtures.radarrServicesJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadTvDetails(tmdbId: 1399, using: client)

        XCTAssertNotNil(viewModel.directorShelf)
        XCTAssertEqual(viewModel.directorShelf?.name, "Vince Gilligan")
    }

    func testLoadTvDetailsPopulatesLeadActorShelf() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/person/") && path.contains("/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else if path.contains("/tv/1399/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/tv/1399/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/tv/1399") {
                data = TestFixtures.tvDetailsWithCrewJSON
            } else if path.contains("/service/sonarr/") {
                data = TestFixtures.radarrServiceDetailsJSON
            } else if path.contains("/service/sonarr") {
                data = TestFixtures.radarrServicesJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadTvDetails(tmdbId: 1399, using: client)

        XCTAssertNotNil(viewModel.leadActorShelf)
        XCTAssertEqual(viewModel.leadActorShelf?.name, "Bryan Cranston")
    }

    // MARK: - Shelf sorting and capping

    func testDirectorShelfItemsSortedByRatingDescending() async {
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/person/") && path.contains("/combined_credits") {
                data = TestFixtures.personCombinedCreditsJSON
            } else if path.contains("/movie/550/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/movie/550/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsWithCrewJSON
            } else if path.contains("/service/radarr/") {
                data = TestFixtures.radarrServiceDetailsJSON
            } else if path.contains("/service/radarr") {
                data = TestFixtures.radarrServicesJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadMovieDetails(tmdbId: 550, using: client)

        if let items = viewModel.directorShelf?.items, items.count > 1 {
            for i in 0..<(items.count - 1) {
                XCTAssertGreaterThanOrEqual(
                    items[i].voteAverage ?? 0,
                    items[i + 1].voteAverage ?? 0,
                    "Director shelf items should be sorted by rating descending"
                )
            }
        }
    }

    // MARK: - No credits graceful handling

    func testNoCreditsProducesNoShelves() async {
        // Use original movie details fixture which has no crew
        MockURLProtocol.requestHandler = { request in
            let path = request.url!.path
            let data: Data
            if path.contains("/movie/550/similar") {
                data = TestFixtures.similarMoviesJSON
            } else if path.contains("/movie/550/recommendations") {
                data = TestFixtures.recommendedMoviesJSON
            } else if path.contains("/movie/550") {
                data = TestFixtures.movieDetailsJSON // No crew in this fixture
            } else if path.contains("/service/radarr/") {
                data = TestFixtures.radarrServiceDetailsJSON
            } else if path.contains("/service/radarr") {
                data = TestFixtures.radarrServicesJSON
            } else {
                data = Data()
            }
            let response = TestFixtures.httpResponse(url: request.url!)
            return (response, data)
        }

        await viewModel.loadMovieDetails(tmdbId: 550, using: client)

        // The original fixture has no crew, so director shelf should be nil
        XCTAssertNil(viewModel.directorShelf)
    }

    // MARK: - mediaItemFrom static helpers

    func testMediaItemFromCastCredit() {
        let credit = PersonCreditCast(
            id: 100,
            mediaType: "movie",
            title: "Test Movie",
            name: nil,
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            voteAverage: 7.5,
            character: "Hero",
            releaseDate: "2020-06-15",
            firstAirDate: nil,
            mediaInfo: nil
        )

        let item = DetailViewModel.mediaItemFrom(credit: credit, mediaType: "movie")

        XCTAssertNotNil(item)
        XCTAssertEqual(item?.tmdbId, 100)
        XCTAssertEqual(item?.title, "Test Movie")
        XCTAssertEqual(item?.year, 2020)
        XCTAssertEqual(item?.mediaType, .movie)
        XCTAssertEqual(item?.voteAverage, 7.5)
    }

    func testMediaItemFromCastCreditReturnsNilForUnknownType() {
        let credit = PersonCreditCast(
            id: 100,
            mediaType: "unknown",
            title: "Test",
            name: nil,
            posterPath: nil,
            backdropPath: nil,
            voteAverage: nil,
            character: nil,
            releaseDate: nil,
            firstAirDate: nil,
            mediaInfo: nil
        )

        XCTAssertNil(DetailViewModel.mediaItemFrom(credit: credit, mediaType: "unknown"))
    }

    func testMediaItemFromCrewCredit() {
        let credit = PersonCreditCrew(
            id: 200,
            mediaType: "tv",
            title: nil,
            name: "Test Show",
            posterPath: "/poster.jpg",
            backdropPath: nil,
            voteAverage: 8.0,
            job: "Director",
            department: "Directing",
            releaseDate: nil,
            firstAirDate: "2018-03-01",
            mediaInfo: nil
        )

        let item = DetailViewModel.mediaItemFrom(crewCredit: credit, mediaType: "tv")

        XCTAssertNotNil(item)
        XCTAssertEqual(item?.tmdbId, 200)
        XCTAssertEqual(item?.title, "Test Show")
        XCTAssertEqual(item?.year, 2018)
        XCTAssertEqual(item?.mediaType, .tv)
    }
}
