import XCTest
@testable import Curator

@MainActor
final class HiddenGemsTests: XCTestCase {

    private var viewModel: HomeViewModel!

    override func setUp() {
        super.setUp()
        viewModel = HomeViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Hidden Gems derivation

    func testHiddenGemsExcludesMainstreamItems() {
        let mainstream = makeItem(id: 1, rating: 8.0, type: .movie)
        viewModel.trendingMovies = [mainstream]
        viewModel.popularMovies = []
        viewModel.recommendationShelves = [
            HomeViewModel.RecommendationShelf(
                id: "rec-1",
                title: "For You",
                items: [
                    mainstream, // same as trending — should be excluded
                    makeItem(id: 2, rating: 7.5, type: .movie), // not mainstream — included
                ]
            ),
        ]

        viewModel.deriveHiddenGems()

        XCTAssertEqual(viewModel.hiddenGems.count, 1)
        XCTAssertEqual(viewModel.hiddenGems[0].tmdbId, 2)
    }

    func testHiddenGemsFiltersOutLowRated() {
        viewModel.trendingMovies = []
        viewModel.popularMovies = []
        viewModel.recommendationShelves = [
            HomeViewModel.RecommendationShelf(
                id: "rec-1",
                title: "Recs",
                items: [
                    makeItem(id: 1, rating: 6.9, type: .movie), // Below 7.0 threshold
                    makeItem(id: 2, rating: 7.0, type: .movie), // At threshold
                    makeItem(id: 3, rating: 8.5, type: .movie), // Above threshold
                ]
            ),
        ]

        viewModel.deriveHiddenGems()

        XCTAssertEqual(viewModel.hiddenGems.count, 2)
        XCTAssertFalse(viewModel.hiddenGems.contains(where: { $0.tmdbId == 1 }))
    }

    func testHiddenGemsSortedByRatingDescending() {
        viewModel.trendingMovies = []
        viewModel.popularMovies = []
        viewModel.recommendationShelves = [
            HomeViewModel.RecommendationShelf(
                id: "rec-1",
                title: "Recs",
                items: [
                    makeItem(id: 1, rating: 7.2, type: .movie),
                    makeItem(id: 2, rating: 9.0, type: .movie),
                    makeItem(id: 3, rating: 7.8, type: .movie),
                ]
            ),
        ]

        viewModel.deriveHiddenGems()

        XCTAssertEqual(viewModel.hiddenGems[0].tmdbId, 2) // 9.0
        XCTAssertEqual(viewModel.hiddenGems[1].tmdbId, 3) // 7.8
        XCTAssertEqual(viewModel.hiddenGems[2].tmdbId, 1) // 7.2
    }

    func testHiddenGemsCapsAt15() {
        viewModel.trendingMovies = []
        viewModel.popularMovies = []
        var items: [MediaItem] = []
        for i in 1...20 {
            items.append(makeItem(id: i, rating: 7.0 + Double(i) * 0.05, type: .movie))
        }
        viewModel.recommendationShelves = [
            HomeViewModel.RecommendationShelf(id: "rec-1", title: "Recs", items: items),
        ]

        viewModel.deriveHiddenGems()

        XCTAssertEqual(viewModel.hiddenGems.count, 15)
    }

    func testHiddenGemsEmptyWhenNoRecommendations() {
        viewModel.trendingMovies = [makeItem(id: 1, rating: 8.0, type: .movie)]
        viewModel.popularMovies = []
        viewModel.recommendationShelves = []

        viewModel.deriveHiddenGems()

        XCTAssertTrue(viewModel.hiddenGems.isEmpty)
    }

    func testHiddenGemsExcludesPopularItems() {
        viewModel.trendingMovies = []
        viewModel.popularMovies = [makeItem(id: 5, rating: 8.0, type: .movie)]
        viewModel.recommendationShelves = [
            HomeViewModel.RecommendationShelf(
                id: "rec-1",
                title: "Recs",
                items: [
                    makeItem(id: 5, rating: 8.0, type: .movie), // in popular
                    makeItem(id: 6, rating: 7.5, type: .movie), // not in popular
                ]
            ),
        ]

        viewModel.deriveHiddenGems()

        XCTAssertEqual(viewModel.hiddenGems.count, 1)
        XCTAssertEqual(viewModel.hiddenGems[0].tmdbId, 6)
    }

    func testHiddenGemsHandlesNilRating() {
        viewModel.trendingMovies = []
        viewModel.popularMovies = []
        viewModel.recommendationShelves = [
            HomeViewModel.RecommendationShelf(
                id: "rec-1",
                title: "Recs",
                items: [
                    MediaItem(
                        id: "movie-1", tmdbId: 1, mediaType: .movie,
                        title: "No Rating", year: 2024, overview: nil,
                        posterPath: nil, backdropPath: nil,
                        voteAverage: nil, genreIds: [], availability: .none
                    ),
                ]
            ),
        ]

        viewModel.deriveHiddenGems()

        XCTAssertTrue(viewModel.hiddenGems.isEmpty)
    }

    func testHiddenGemsExcludesTrendingShows() {
        viewModel.trendingMovies = []
        viewModel.trendingShows = [makeItem(id: 10, rating: 8.5, type: .tv)]
        viewModel.popularMovies = []
        viewModel.recommendationShelves = [
            HomeViewModel.RecommendationShelf(
                id: "rec-1",
                title: "Recs",
                items: [
                    makeItem(id: 10, rating: 8.5, type: .tv), // in trending shows
                    makeItem(id: 11, rating: 7.5, type: .tv), // not in trending
                ]
            ),
        ]

        viewModel.deriveHiddenGems()

        XCTAssertEqual(viewModel.hiddenGems.count, 1)
        XCTAssertEqual(viewModel.hiddenGems[0].tmdbId, 11)
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
