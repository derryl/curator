# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Curator is a native tvOS SwiftUI app (Swift 6, tvOS 17+) for discovering and requesting movies/TV shows. It uses Overseerr as the backend for media requests and availability, with optional Trakt integration for personalized recommendations. Zero third-party dependencies — Apple frameworks only.

## Build Commands

```bash
# Generate Xcode project (required after adding/removing files or changing project.yml)
xcodegen generate

# Build from command line
xcodebuild build -project Curator.xcodeproj -scheme Curator \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'

# Run all unit tests
xcodebuild test -project Curator.xcodeproj -scheme CuratorTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'

# Run a single test class
xcodebuild test -project Curator.xcodeproj -scheme CuratorTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:CuratorTests/YouTubeStreamExtractorTests

# Run UI tests
xcodebuild test -project Curator.xcodeproj -scheme CuratorUITests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

## Secrets Configuration

Credentials live in `Curator/Config/Secrets.xcconfig` (gitignored). Copy from `Secrets.xcconfig.example` and fill in real values. These are read via Info.plist keys at runtime. Never hardcode API keys in source files.

## Architecture

MVVM with `@Observable` (Swift 5.9+ macro), async/await concurrency, actor-based API clients:

```
SwiftUI Views → @Observable ViewModels → actor Services → Codable Models
```

### Three Integrated APIs

| Service | Role | Auth |
|---------|------|------|
| **Overseerr** (required) | Request submission, media details, availability, proxied TMDB metadata+images | API Key header |
| **Trakt** (optional) | Personalized discovery, trending, anticipated, most-watched, watch history | OAuth 2.0 Device Code Flow |
| **TMDB** (indirect) | Images and metadata proxied through Overseerr — no separate API key needed | N/A |

Key insight: Overseerr's `/movie/{tmdbId}` and `/tv/{tmdbId}` return TMDB metadata AND availability in one call. For Trakt-sourced items (which include `tmdb_id`), we call Overseerr to resolve images+availability — this is what `MediaResolver` does.

### Core Components

- **AppState** (`App/AppState.swift`) — Global `@Observable` singleton managing all service lifecycle, auth status, and connection flags
- **MediaResolver** (`Services/MediaResolver.swift`) — Bridges Trakt items → Overseerr-enriched `MediaItem` objects (the cross-API orchestration layer)
- **MediaItem** (`Models/MediaItem.swift`) — Unified display model with `id` format `"movie-{tmdbId}"` or `"tv-{tmdbId}"`, includes `AvailabilityStatus` from Overseerr
- **HomeViewModel** — Orchestrates shelf loading, deduplication across shelves, derived shelves (top-rated, hidden gems), availability-priority sorting

### Navigation Structure

- Root `TabView` with 4 tabs: Home, Browse, Search, Settings
- Each tab uses independent `NavigationStack` (not `NavigationSplitView`)
- `.onExitCommand` on non-Home tabs returns to Home; on Home, scrolls to top
- Detail views are pushed via `navigationDestination`

### Storage

- **Keychain** (via `KeychainHelper`): API keys, auth tokens
- **UserDefaults** (via `UserDefaultsKeys`): Connection config, onboarding state, Trakt connection flag

## tvOS-Specific Patterns

- `.buttonStyle(.card)` on `MediaCard` — native lift/scale/parallax focus effects
- `.focusSection()` on each `MediaShelfView` — enables up/down between shelves, left/right within
- `TabView` renders as auto-hiding top bar (native tvOS, different from iOS)
- Trailer playback uses `AVPlayerViewController` with `appliesPreferredDisplayCriteriaAutomatically = false` to prevent Dolby Vision black screen flash
- YouTube stream extraction filters to tvOS-safe codecs only (H.264/H.265 video, AAC audio) — VP9/AV1/Opus are rejected

## Testing

All network tests use `MockURLProtocol` (in `CuratorTests/Helpers/`) to intercept URLSession requests. Test fixtures live in `CuratorTests/Helpers/TestFixtures.swift`. No external testing frameworks — XCTest only.

`YouTubeLiveIntegrationTests` hits real YouTube servers — these may be flaky in CI.

## XcodeGen

The `.xcodeproj` is generated from `project.yml`. After adding or removing Swift files, run `xcodegen generate` to regenerate. Both app and test targets are defined in `project.yml`.

## Known Behaviors

- tvOS simulator icon cache is aggressive — after icon changes: clean build + uninstall + reboot simulator + reinstall
- Bundle ID is lowercase: `com.derryl.curator` (not `com.derryl.Curator`)
- `print()` doesn't appear in unified log on Apple platforms; use `NSLog` or `os.Logger` for debugging
- Trakt rate limit: 1000 GET requests per 5 minutes

## Key Documentation

- `PLAN.md` — Comprehensive architecture doc with all API endpoints, auth flows, screen breakdown, and implementation phases
- `RECOMMENDATION_ENGINE.md` — Feature roadmap for recommendation engine with implementation tracker (Phases 1-3)
- `.claude/TODO.md` — Detailed implementation status and known issues

---

## Development Guidelines

These guidelines define how to build, test, and verify changes in Curator. Follow them for every feature, bugfix, and refactor.

### Swift 6 Concurrency

This project uses strict Swift 6 concurrency. All code must be data-race safe.

- API clients (`OverseerrClient`, `TraktClient`, `MediaResolver`) are `actor` types. Access their methods with `await`.
- `TraktAuthManager` is a `final class` marked `Sendable` (stores tokens in Keychain, which is thread-safe). It is shared across actors without isolation.
- All ViewModels are `@MainActor @Observable final class`. Their public methods are implicitly `@MainActor`.
- Use `nonisolated static func` for pure data-fetching helpers that don't access `self` — this avoids MainActor re-entry overhead and enables parallel execution via `async let`. See `HomeViewModel.fetchTraktTrendingMovies(...)` for the pattern.
- Models (`MediaItem`, all Overseerr/Trakt response types) are `Sendable` structs. Never use classes for API response models.
- Use `withTaskGroup` for fan-out patterns (resolving N items in parallel). See `MediaResolver.resolveMovies()`.
- Use `async let` for fixed-count concurrent operations. See `HomeViewModel.loadTraktContent()` (11 concurrent shelf loads) and `DetailViewModel.loadMovieDetails()` (3 concurrent loads).
- Handle `CancellationError` explicitly in search/debounce contexts — don't surface it as a user error. See `SearchViewModel.search()`.

### Adding New Files

After creating or deleting any `.swift` file, regenerate the Xcode project:

```bash
xcodegen generate
```

XcodeGen auto-discovers sources in the `Curator/`, `CuratorTests/`, and `CuratorUITests/` directories. No manual target membership needed — just place files in the correct directory.

### API Client Conventions

When adding new API endpoints:

- Add the method to the appropriate actor (`OverseerrClient` or `TraktClient`).
- Use the existing `get<T: Decodable>()` or `post<T: Decodable>()` generic helpers — don't create raw URLRequest code.
- Overseerr endpoints always include `/api/v1/` prefix. Trakt endpoints use `https://api.trakt.tv/`.
- Trakt methods accept an `authenticated: Bool` parameter (default `false`). Set `true` for endpoints requiring user tokens (`/recommendations`, `/sync/history`).
- Return Codable model types, not raw Data or JSON dictionaries.
- For new Overseerr response types, handle TMDB's inconsistent nesting gracefully in custom `init(from decoder:)` — see `OverseerrMovieDetails` for the keywords wrapper pattern.

### Model Conventions

- All display data flows through `MediaItem`. Add a `static func from(...)` factory method for each new data source.
- `MediaItem.id` format is `"{mediaType}-{tmdbId}"` (e.g. `"movie-550"`, `"tv-1399"`). This enables deduplication across sources.
- `AvailabilityStatus` determines request button visibility and shelf sort order via `requestPriority`.
- New Trakt response models go in `Models/Trakt/`, Overseerr models in `Models/Overseerr/`.

### View & Component Conventions

#### Layout Constants

| Token | Value | Usage |
|-------|-------|-------|
| Horizontal page margin | 60pt | `.padding(.horizontal, 60)` on all top-level sections |
| Shelf item spacing | 30pt | `LazyHStack(spacing: 30)` in `MediaShelfView` |
| Section spacing | 40pt | `VStack(spacing: 40)` or `LazyVStack(spacing: 40)` between shelves |
| Card corner radius | 12pt | `RoundedRectangle(cornerRadius: 12)` on cards and posters |
| Hero height | 650pt | `BackdropHeroView` frame height |
| Poster card size | 240×360 | `MediaCard` fixed frame (2:3 aspect ratio) |
| Hero poster size | 200×300 | Poster inset within `BackdropHeroView` |

#### tvOS Focus & Navigation

- Wrap every horizontally-scrollable region in `.focusSection()` — this is required for the Siri Remote d-pad to navigate up/down between shelves and left/right within them.
- Use `.buttonStyle(.card)` (or the custom `.focusableCard` style) on all interactive cards — this provides the native tvOS lift, scale, parallax, and shadow on focus.
- Use `@FocusState` and `prefersDefaultFocus(in:)` with `@Namespace` to control initial focus placement on detail screens. See `MovieDetailView` for the pattern.
- Handle `.onExitCommand` on every `NavigationStack` to implement consistent Menu button behavior.
- Use `NavigationStack` with `navigationDestination(for:)` — never `NavigationSplitView` or `NavigationLink(destination:)`.

#### Image Handling

- Poster URLs: `ImageService.posterURL(path, size:)` — default `.w500`, use `.w342` in hero views.
- Backdrop URLs: `ImageService.backdropURL(path)` — always `.original` size.
- Use `AsyncImage` with a `ProgressView` placeholder during loading and a `RoundedRectangle` with `film` SF Symbol for failures.
- Never import Kingfisher, Nuke, or SDWebImage — `AsyncImage` with system URL cache is sufficient for this single-user app.

#### Accessibility Identifiers

Add accessibility identifiers to all testable UI elements. Existing conventions:

| Identifier | Component |
|------------|-----------|
| `hero_title` | `BackdropHeroView` title text |
| `media_shelf` | `MediaShelfView` container |
| `tab_home`, `tab_browse`, `tab_search`, `tab_settings` | `ContentView` tabs |
| `button_trailer` | Trailer play button on detail views |
| `button_request_{profileId}` | Request buttons on detail views |
| `status_pill` | `StatusPill` on detail views |
| `section_overview` | Overview section header |

New interactive or content-bearing elements must have an identifier following the `{component}_{descriptor}` pattern.

### Writing Unit Tests

Every new feature or bugfix must include unit tests. Follow these patterns exactly.

#### Test File Setup

```swift
import XCTest
@testable import Curator

final class MyFeatureTests: XCTestCase {
    private var client: OverseerrClient!

    override func setUp() {
        super.setUp()
        let session = TestFixtures.mockSession()
        client = OverseerrClient(
            baseURL: URL(string: "https://overseerr.example.com")!,
            apiKey: "test-api-key",
            session: session
        )
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        client = nil
        super.tearDown()
    }
}
```

- Always use `TestFixtures.mockSession()` — never `URLSession.shared` in unit tests.
- Always nil out `MockURLProtocol.requestHandler` in `tearDown` to prevent test pollution.
- Place test files in `CuratorTests/` with the suffix `Tests.swift`.

#### Mocking Network Responses

Set `MockURLProtocol.requestHandler` to a closure that inspects the request and returns fixture data:

```swift
MockURLProtocol.requestHandler = { request in
    let path = request.url!.path
    let data: Data
    if path.contains("/movie/550/similar") {
        data = TestFixtures.similarMoviesJSON
    } else if path.contains("/movie/550") {
        data = TestFixtures.movieDetailsJSON
    } else {
        data = Data()  // fallback
    }
    return (TestFixtures.httpResponse(url: request.url!), data)
}
```

- Route by URL path using `path.contains(...)` — a single handler serves multiple endpoints.
- Add new fixture properties to `TestFixtures.swift` as `static var` computed properties returning `Data`.
- Build fixture JSON using `JSONSerialization.data(withJSONObject:)` with `try!` — this catches structural errors at compile time.

#### Testing Request Shape

Capture the request to verify HTTP method, headers, URL path, query parameters, and body:

```swift
var capturedRequest: URLRequest?
MockURLProtocol.requestHandler = { request in
    capturedRequest = request
    return (TestFixtures.httpResponse(url: request.url!), TestFixtures.someJSON)
}

_ = try await client.someMethod(param: "value")

let request = try XCTUnwrap(capturedRequest)
XCTAssertEqual(request.httpMethod, "POST")

// For POST bodies, read httpBodyStream (httpBody is nil inside URLProtocol):
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
    // Parse and assert on bodyData
}

// For query parameters:
let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
let queryItems = components?.queryItems ?? []
XCTAssertTrue(queryItems.contains(where: { $0.name == "page" && $0.value == "2" }))
```

#### Testing ViewModels

Mark ViewModel test classes `@MainActor` since ViewModels are MainActor-isolated:

```swift
@MainActor
final class MyViewModelTests: XCTestCase {
    func testLoadsContent() async {
        let vm = MyViewModel()
        await vm.loadContent(using: client)

        XCTAssertEqual(vm.items.count, 5)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }
}
```

- Verify the full state triple: content populated, `isLoading == false`, `errorMessage == nil`.
- Test error paths: set handler to return HTTP 500, verify `errorMessage` is set and content is empty or unchanged.
- Test pagination: call `loadMore()` and verify items append (not replace). See `KeywordDiscoveryTests.testKeywordBrowseViewModelAppendsOnSubsequentPages`.

#### Testing Error Paths

```swift
func testHandlesServerError() async {
    MockURLProtocol.requestHandler = { request in
        let response = TestFixtures.httpResponse(url: request.url!, statusCode: 500)
        return (response, Data())
    }

    do {
        _ = try await client.someMethod()
        XCTFail("Expected error to be thrown")
    } catch let error as OverseerrError {
        if case .httpError(let code, _) = error {
            XCTAssertEqual(code, 500)
        } else {
            XCTFail("Unexpected error case: \(error)")
        }
    } catch {
        XCTFail("Unexpected error type: \(error)")
    }
}
```

#### Testing Model Decoding

Test Codable conformance, Hashable/Equatable behavior, and edge cases:

```swift
func testKeywordIsHashable() {
    let a = OverseerrKeyword(id: 1, name: "heist")
    let b = OverseerrKeyword(id: 1, name: "heist")
    let c = OverseerrKeyword(id: 2, name: "heist")
    XCTAssertEqual(a, b)
    XCTAssertNotEqual(a, c)

    let set: Set<OverseerrKeyword> = [a, b, c]
    XCTAssertEqual(set.count, 2)
}
```

### Writing UI Tests (E2E)

UI tests verify navigation flows, content loading, and visual state on the tvOS simulator with a live Overseerr backend.

#### Test File Setup

```swift
import XCTest

@MainActor
final class MyFlowTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
}
```

- Place UI test files in `CuratorUITests/`.
- `continueAfterFailure = false` stops on first failure — subsequent assertions would be meaningless after a navigation failure.

#### tvOS Remote Navigation

Use `XCUIRemote.shared` to simulate the Siri Remote:

```swift
let remote = XCUIRemote.shared
remote.press(.right)    // D-pad right
remote.press(.left)     // D-pad left
remote.press(.up)       // D-pad up
remote.press(.down)     // D-pad down
remote.press(.select)   // Click/tap center
remote.press(.menu)     // Back/Menu button
```

#### Finding Elements

Use accessibility identifiers — never rely on label text (it changes with content):

```swift
let shelf = app.descendants(matching: .any).matching(identifier: "media_shelf").firstMatch
XCTAssertTrue(shelf.waitForExistence(timeout: 15))
```

- Use `waitForExistence(timeout:)` for all elements that depend on network data. 15 seconds accommodates slow Overseerr responses.
- Use `descendants(matching: .any).matching(identifier:)` — more reliable on tvOS than `app.buttons["id"]`.

#### Screenshot Capture

Capture screenshots for visual verification and attach to test results:

```swift
let screenshot = app.screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.name = "Home Tab - Shelves Loaded"
attachment.lifetime = .keepAlways
add(attachment)
```

Screenshots are saved in the Xcode test result bundle at `DerivedData/.../Attachments/`.

### Running Tests

```bash
# All unit tests
xcodebuild test -project Curator.xcodeproj -scheme CuratorTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'

# Single test class
xcodebuild test -project Curator.xcodeproj -scheme CuratorTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:CuratorTests/KeywordDiscoveryTests

# Single test method
xcodebuild test -project Curator.xcodeproj -scheme CuratorTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:CuratorTests/KeywordDiscoveryTests/testKeywordIsIdentifiable

# UI tests (requires tvOS simulator with configured Overseerr connection)
xcodebuild test -project Curator.xcodeproj -scheme CuratorUITests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

After writing or modifying tests, always run them to confirm they pass before committing.

### Visual Verification with Screenshots

When changes affect layout, spacing, focus behavior, or visual appearance, verify with the Playwright MCP or by capturing simulator screenshots:

```bash
# Take a simulator screenshot
xcrun simctl io booted screenshot /tmp/curator_screenshot.png
```

Then read the screenshot file to visually inspect the result. This is especially important for:

- Hero view layout changes (650pt height, gradient overlays, poster+metadata alignment)
- Focus state appearance (card lift/scale/shadow)
- Status pill placement within action button rows
- Shelf spacing and horizontal scroll behavior
- New component additions to detail views

### Graceful Degradation

The app must always show content, even when services are partially unavailable:

1. **Trakt + Overseerr available** — Full personalized experience with availability badges.
2. **Overseerr only (no Trakt)** — Falls back to Overseerr discover endpoints. `HomeViewModel.loadOverseerrContent()` replaces `loadTraktContent()`.
3. **Trakt item fails Overseerr resolution** — `MediaResolver` falls back to `MediaItem.from(traktMovie:)` with title/year only (no poster).
4. **Individual shelf load fails** — Silently returns `[]` via `try?`. Other shelves still render.

When adding new data sources or shelves, follow this pattern: wrap the fetch in `try?` or catch-and-return-empty so a single failure never breaks the home screen.

### Deduplication

`HomeViewModel.deduplicateShelves()` runs after all shelves load. It ensures each `MediaItem` appears in at most one shelf, prioritizing earlier shelves (recommendations > trending > popular > derived).

When adding a new shelf:
1. Add the property to `HomeViewModel`.
2. Include it in `deduplicateShelves()` in the appropriate priority position.
3. Add it to `HomeView`'s `LazyVStack` with a conditional `if !shelf.isEmpty`.

### Reference Documentation

- [Apple tvOS Human Interface Guidelines — Focus and Navigation](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- [SwiftUI on tvOS — Focus Management](https://developer.apple.com/documentation/swiftui/focus)
- [Swift Concurrency — Actors](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/#Actors)
- [Overseerr API](https://api-docs.overseerr.dev/)
- [Trakt API](https://trakt.docs.apiary.io/)
- [XCTest — Testing Asynchronous Code](https://developer.apple.com/documentation/xctest/asynchronous_tests_and_expectations)
