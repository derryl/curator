import XCTest
@testable import Curator

final class TraktModelsTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - TraktAnticipatedMovie

    func testDecodeTraktAnticipatedMovie() throws {
        let json = """
        {
            "list_count": 42,
            "movie": {
                "title": "Dune: Part Three",
                "year": 2026,
                "ids": { "trakt": 12345, "slug": "dune-part-three", "tmdb": 67890 }
            }
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(TraktAnticipatedMovie.self, from: json)
        XCTAssertEqual(item.listCount, 42)
        XCTAssertEqual(item.movie.title, "Dune: Part Three")
        XCTAssertEqual(item.movie.year, 2026)
        XCTAssertEqual(item.movie.ids.tmdb, 67890)
    }

    func testDecodeTraktAnticipatedShow() throws {
        let json = """
        {
            "list_count": 100,
            "show": {
                "title": "The Last of Us",
                "year": 2023,
                "ids": { "trakt": 11111, "slug": "the-last-of-us", "tmdb": 22222 }
            }
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(TraktAnticipatedShow.self, from: json)
        XCTAssertEqual(item.listCount, 100)
        XCTAssertEqual(item.show.title, "The Last of Us")
    }

    // MARK: - TraktMostWatchedMovie

    func testDecodeTraktMostWatchedMovie() throws {
        let json = """
        {
            "watcher_count": 5000,
            "play_count": 12000,
            "movie": {
                "title": "Oppenheimer",
                "year": 2023,
                "ids": { "trakt": 33333, "slug": "oppenheimer", "tmdb": 44444 }
            }
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(TraktMostWatchedMovie.self, from: json)
        XCTAssertEqual(item.watcherCount, 5000)
        XCTAssertEqual(item.playCount, 12000)
        XCTAssertEqual(item.movie.title, "Oppenheimer")
        XCTAssertEqual(item.movie.ids.tmdb, 44444)
    }

    func testDecodeTraktMostWatchedShow() throws {
        let json = """
        {
            "watcher_count": 8000,
            "play_count": 25000,
            "show": {
                "title": "Severance",
                "year": 2022,
                "ids": { "trakt": 55555, "slug": "severance", "tmdb": 66666 }
            }
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(TraktMostWatchedShow.self, from: json)
        XCTAssertEqual(item.watcherCount, 8000)
        XCTAssertEqual(item.playCount, 25000)
        XCTAssertEqual(item.show.title, "Severance")
    }

    // MARK: - Array decoding (API returns arrays)

    func testDecodeAnticipatedMoviesArray() throws {
        let json = """
        [
            {
                "list_count": 10,
                "movie": {
                    "title": "Movie A",
                    "year": 2025,
                    "ids": { "trakt": 1, "slug": "movie-a", "tmdb": 100 }
                }
            },
            {
                "list_count": 5,
                "movie": {
                    "title": "Movie B",
                    "year": 2025,
                    "ids": { "trakt": 2, "slug": "movie-b", "tmdb": 200 }
                }
            }
        ]
        """.data(using: .utf8)!

        let items = try decoder.decode([TraktAnticipatedMovie].self, from: json)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].listCount, 10)
        XCTAssertEqual(items[1].movie.title, "Movie B")
    }

    func testDecodeMostWatchedShowsArray() throws {
        let json = """
        [
            {
                "watcher_count": 3000,
                "play_count": 9000,
                "show": {
                    "title": "Show A",
                    "year": 2024,
                    "ids": { "trakt": 10, "slug": "show-a", "tmdb": 1000 }
                }
            }
        ]
        """.data(using: .utf8)!

        let items = try decoder.decode([TraktMostWatchedShow].self, from: json)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].show.ids.tmdb, 1000)
    }
}
