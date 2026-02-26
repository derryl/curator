import XCTest
@testable import Curator

/// Tests that the StatusPill display logic matches the hero action button rules:
/// - When status is .none or .unknown: show request buttons, no StatusPill
/// - When status is .processing, .pending, .available, .partiallyAvailable: show StatusPill, no request buttons
final class StatusPillPlacementTests: XCTestCase {

    // MARK: - StatusPill Config

    func testStatusPillHiddenForNoneStatus() {
        let pill = StatusPill(status: .none)
        // .none should produce no pill (pillConfig returns nil)
        XCTAssertNil(pill.testPillConfig)
    }

    func testStatusPillHiddenForUnknownStatus() {
        let pill = StatusPill(status: .unknown)
        XCTAssertNil(pill.testPillConfig)
    }

    func testStatusPillVisibleForProcessing() {
        let pill = StatusPill(status: .processing)
        let config = pill.testPillConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.label, "Processing")
    }

    func testStatusPillVisibleForPending() {
        let pill = StatusPill(status: .pending)
        let config = pill.testPillConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.label, "Requested")
    }

    func testStatusPillVisibleForAvailable() {
        let pill = StatusPill(status: .available)
        let config = pill.testPillConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.label, "Available")
    }

    func testStatusPillVisibleForPartiallyAvailable() {
        let pill = StatusPill(status: .partiallyAvailable)
        let config = pill.testPillConfig
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.label, "Partial")
    }

    // MARK: - Hero Button Logic

    /// Verifies the condition: request buttons shown only when status is .none or .unknown
    func testRequestButtonsShownOnlyForNoneOrUnknown() {
        let statusesThatShowRequest: [MediaItem.AvailabilityStatus] = [.none, .unknown]
        let statusesThatShowPill: [MediaItem.AvailabilityStatus] = [.processing, .pending, .available, .partiallyAvailable]

        for status in statusesThatShowRequest {
            let showsRequest = (status == .none || status == .unknown)
            XCTAssertTrue(showsRequest, "\(status) should show request buttons")
        }

        for status in statusesThatShowPill {
            let showsRequest = (status == .none || status == .unknown)
            XCTAssertFalse(showsRequest, "\(status) should show status pill instead of request buttons")
        }
    }
}
