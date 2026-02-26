import XCTest
@testable import Curator

final class AvailabilityPriorityTests: XCTestCase {

    // MARK: - requestPriority ordering

    func testRequestPriorityNoneIsLowest() {
        XCTAssertEqual(MediaItem.AvailabilityStatus.none.requestPriority, 0)
    }

    func testRequestPriorityUnknownIsSecond() {
        XCTAssertEqual(MediaItem.AvailabilityStatus.unknown.requestPriority, 1)
    }

    func testRequestPriorityAvailableIsHighest() {
        XCTAssertEqual(MediaItem.AvailabilityStatus.available.requestPriority, 5)
    }

    func testRequestPriorityOrderIsCorrect() {
        let statuses: [MediaItem.AvailabilityStatus] = [
            .none, .unknown, .partiallyAvailable, .pending, .processing, .available
        ]
        let priorities = statuses.map(\.requestPriority)
        XCTAssertEqual(priorities, priorities.sorted(),
                       "Priorities should be in ascending order from most to least actionable")
    }

    // MARK: - sortByRequestPriority

    func testSortByRequestPriorityPutsNoneFirst() {
        let items = [
            makeItem(id: 1, availability: .available),
            makeItem(id: 2, availability: .none),
            makeItem(id: 3, availability: .pending),
            makeItem(id: 4, availability: .none),
            makeItem(id: 5, availability: .processing),
        ]

        let sorted = HomeViewModel.sortByRequestPriority(items)

        XCTAssertEqual(sorted[0].tmdbId, 2)
        XCTAssertEqual(sorted[1].tmdbId, 4)
        XCTAssertEqual(sorted.last?.tmdbId, 1) // .available is last
    }

    func testSortByRequestPriorityPreservesOrderWithinSamePriority() {
        let items = [
            makeItem(id: 10, availability: .none),
            makeItem(id: 20, availability: .none),
            makeItem(id: 30, availability: .none),
        ]

        let sorted = HomeViewModel.sortByRequestPriority(items)

        // All have same priority, so order should be preserved (stable sort)
        XCTAssertEqual(sorted.map(\.tmdbId), [10, 20, 30])
    }

    func testSortByRequestPriorityFullOrdering() {
        let items = [
            makeItem(id: 1, availability: .available),
            makeItem(id: 2, availability: .processing),
            makeItem(id: 3, availability: .none),
            makeItem(id: 4, availability: .pending),
            makeItem(id: 5, availability: .unknown),
            makeItem(id: 6, availability: .partiallyAvailable),
        ]

        let sorted = HomeViewModel.sortByRequestPriority(items)
        let priorities = sorted.map(\.availability.requestPriority)

        XCTAssertEqual(priorities, priorities.sorted(),
                       "Items should be sorted by requestPriority ascending")
    }

    func testSortByRequestPriorityEmptyArray() {
        let sorted = HomeViewModel.sortByRequestPriority([])
        XCTAssertTrue(sorted.isEmpty)
    }

    // MARK: - Helpers

    private func makeItem(id: Int, availability: MediaItem.AvailabilityStatus) -> MediaItem {
        MediaItem(
            id: "movie-\(id)",
            tmdbId: id,
            mediaType: .movie,
            title: "Movie \(id)",
            year: 2024,
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            voteAverage: 7.0,
            genreIds: [],
            availability: availability
        )
    }
}
