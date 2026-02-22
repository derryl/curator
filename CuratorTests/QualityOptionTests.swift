import XCTest
@testable import Curator

final class QualityOptionTests: XCTestCase {

    func testFilteredExtractsBoth1080pAnd4KProfiles() {
        let profiles = [
            OverseerrQualityProfile(id: 1, name: "Any"),
            OverseerrQualityProfile(id: 4, name: "HD-1080p"),
            OverseerrQualityProfile(id: 7, name: "Ultra-HD 4K"),
        ]

        let options = QualityOption.filtered(from: profiles)

        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].id, "1080")
        XCTAssertEqual(options[0].label, "1080p")
        XCTAssertEqual(options[0].profileId, 4)
        XCTAssertEqual(options[1].id, "4k")
        XCTAssertEqual(options[1].label, "4K")
        XCTAssertEqual(options[1].profileId, 7)
    }

    func testFilteredWith2160pNameVariant() {
        let profiles = [
            OverseerrQualityProfile(id: 10, name: "2160p Remux"),
        ]

        let options = QualityOption.filtered(from: profiles)

        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(options[0].id, "4k")
        XCTAssertEqual(options[0].label, "4K")
    }

    func testFilteredWithUHDNameVariant() {
        let profiles = [
            OverseerrQualityProfile(id: 11, name: "UHD Bluray"),
        ]

        let options = QualityOption.filtered(from: profiles)

        XCTAssertEqual(options.count, 1)
        XCTAssertEqual(options[0].id, "4k")
    }

    func testFilteredReturnsEmptyForNoMatchingProfiles() {
        let profiles = [
            OverseerrQualityProfile(id: 1, name: "Any"),
            OverseerrQualityProfile(id: 2, name: "SD"),
            OverseerrQualityProfile(id: 3, name: "720p"),
        ]

        let options = QualityOption.filtered(from: profiles)

        XCTAssertTrue(options.isEmpty)
    }

    func testFilteredReturnsEmptyForEmptyInput() {
        let options = QualityOption.filtered(from: [])
        XCTAssertTrue(options.isEmpty)
    }

    func testFilteredOnlyReturnsFirstMatchPerTier() {
        let profiles = [
            OverseerrQualityProfile(id: 4, name: "HD-1080p"),
            OverseerrQualityProfile(id: 5, name: "Bluray-1080p"),
            OverseerrQualityProfile(id: 7, name: "Ultra-HD 4K"),
            OverseerrQualityProfile(id: 8, name: "4K HDR"),
        ]

        let options = QualityOption.filtered(from: profiles)

        XCTAssertEqual(options.count, 2)
        // Should take the first match for each tier
        XCTAssertEqual(options[0].profileId, 4) // first 1080p
        XCTAssertEqual(options[1].profileId, 7) // first 4K
    }

    func testFilteredOrderIs1080pThen4K() {
        // Even if 4K appears first in profiles, output should be [1080p, 4K]
        let profiles = [
            OverseerrQualityProfile(id: 7, name: "4K"),
            OverseerrQualityProfile(id: 4, name: "1080p"),
        ]

        let options = QualityOption.filtered(from: profiles)

        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[0].id, "1080")
        XCTAssertEqual(options[1].id, "4k")
    }
}
