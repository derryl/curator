import XCTest
@testable import Curator

@MainActor
final class TopRatedShelfTests: XCTestCase {

    private var viewModel: HomeViewModel!

    override func setUp() {
        super.setUp()
        viewModel = HomeViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Top Rated derivation

    func testTopRatedMoviesDerivedFromPopularAndTrending() {
        viewModel.popularMovies = [
            makeItem(id: 1, rating: 8.5, type: .movie),
            makeItem(id: 2, rating: 6.0, type: .movie),
            makeItem(id: 3, rating: 7.5, type: .movie),
        ]
        viewModel.trendingMovies = [
            makeItem(id: 4, rating: 9.0, type: .movie),
            makeItem(id: 5, rating: 5.0, type: .movie),
        ]

        viewModel.deriveTopRatedShelves()

        XCTAssertEqual(viewModel.topRatedMovies.count, 3)
        XCTAssertEqual(viewModel.topRatedMovies[0].tmdbId, 4) // 9.0
        XCTAssertEqual(viewModel.topRatedMovies[1].tmdbId, 1) // 8.5
        XCTAssertEqual(viewModel.topRatedMovies[2].tmdbId, 3) // 7.5
    }

    func testTopRatedShowsDerivedFromPopularAndTrending() {
        viewModel.popularShows = [
            makeItem(id: 10, rating: 8.9, type: .tv),
            makeItem(id: 11, rating: 7.0, type: .tv),
        ]
        viewModel.trendingShows = [
            makeItem(id: 12, rating: 7.6, type: .tv),
        ]

        viewModel.deriveTopRatedShelves()

        XCTAssertEqual(viewModel.topRatedShows.count, 2)
        XCTAssertEqual(viewModel.topRatedShows[0].tmdbId, 10)
        XCTAssertEqual(viewModel.topRatedShows[1].tmdbId, 12)
    }

    func testTopRatedExcludesItemsBelowThreshold() {
        viewModel.popularMovies = [
            makeItem(id: 1, rating: 7.4, type: .movie),
            makeItem(id: 2, rating: 7.5, type: .movie),
            makeItem(id: 3, rating: 5.0, type: .movie),
        ]

        viewModel.deriveTopRatedShelves()

        XCTAssertEqual(viewModel.topRatedMovies.count, 1)
        XCTAssertEqual(viewModel.topRatedMovies[0].tmdbId, 2)
    }

    func testTopRatedCapsAt15Items() {
        var items: [MediaItem] = []
        for i in 1...20 {
            items.append(makeItem(id: i, rating: 8.0 + Double(i) * 0.01, type: .movie))
        }
        viewModel.popularMovies = items

        viewModel.deriveTopRatedShelves()

        XCTAssertEqual(viewModel.topRatedMovies.count, 15)
    }

    func testTopRatedEmptyWhenNoHighRatedContent() {
        viewModel.popularMovies = [
            makeItem(id: 1, rating: 5.0, type: .movie),
            makeItem(id: 2, rating: 6.5, type: .movie),
        ]

        viewModel.deriveTopRatedShelves()

        XCTAssertTrue(viewModel.topRatedMovies.isEmpty)
    }

    func testTopRatedHandlesNilRatings() {
        viewModel.popularMovies = [
            MediaItem(
                id: "movie-1", tmdbId: 1, mediaType: .movie,
                title: "No Rating", year: 2024, overview: nil,
                posterPath: nil, backdropPath: nil,
                voteAverage: nil, genreIds: [], availability: .none
            ),
            makeItem(id: 2, rating: 8.0, type: .movie),
        ]

        viewModel.deriveTopRatedShelves()

        XCTAssertEqual(viewModel.topRatedMovies.count, 1)
        XCTAssertEqual(viewModel.topRatedMovies[0].tmdbId, 2)
    }

    func testTopRatedIncludesUpcomingContent() {
        viewModel.upcomingMovies = [
            makeItem(id: 1, rating: 8.5, type: .movie),
        ]

        viewModel.deriveTopRatedShelves()

        XCTAssertEqual(viewModel.topRatedMovies.count, 1)
        XCTAssertEqual(viewModel.topRatedMovies[0].tmdbId, 1)
    }

    // MARK: - Helpers

    private func makeItem(id: Int, rating: Double, type: MediaItem.MediaType) -> MediaItem {
        MediaItem(
            id: "\(type.rawValue)-\(id)",
            tmdbId: id,
            mediaType: type,
            title: "Title \(id)",
            year: 2024,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            voteAverage: rating,
            genreIds: [],
            availability: .none
        )
    }
}
