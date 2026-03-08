# Curator - Native tvOS Media Discovery & Overseerr Client

## Overview

**Curator** is a native SwiftUI tvOS app for Apple TV that replaces the browsing/discovery UI of Overseerr with a personalized experience powered by Trakt, while keeping Overseerr as the backend for submitting and tracking media requests.

- **Repo:** `~/playground/curator` (push to `github.com/derryl/curator`)
- **Platform:** tvOS 17+ (SwiftUI, Swift 6)
- **Distribution:** TestFlight
- **Dependencies:** Zero third-party SPM packages (URLSession, AsyncImage, Keychain APIs only)

---

## API Architecture

Three services, each with a specific role:

| Service | Role | Auth Method |
|---------|------|-------------|
| **Trakt** | Discovery & personalization (trending, popular, recommendations from watch history) | OAuth 2.0 Device Code Flow |
| **Overseerr** | Request submission, request status, media details (proxies TMDB metadata + images + availability in one call) | API Key header or username/password |
| **TMDB** | Optional fallback for images when using Trakt-sourced data | API key (optional, Overseerr proxies TMDB) |

**Key insight:** Overseerr's `/movie/{tmdbId}` and `/tv/{tmdbId}` endpoints return TMDB metadata (poster, backdrop, overview, credits) AND availability/request status in a single response. For Trakt-sourced items (which include `tmdb_id`), we call Overseerr to resolve images + availability — no separate TMDB API key needed.

### Overseerr Endpoints Used

From the existing seerr-tv client at `seerr-tv/lib/OverseerrClient/`:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/v1/search?query=X&page=X` | Search movies, TV, people |
| `GET /api/v1/discover/trending?page=X&language=X` | Trending (fallback when Trakt not connected) |
| `GET /api/v1/discover/movies?page=X&language=X` | Discover movies |
| `GET /api/v1/discover/tv?page=X&language=X` | Discover TV |
| `GET /api/v1/discover/movies/upcoming` | Upcoming movies |
| `GET /api/v1/discover/tv/upcoming` | Upcoming TV |
| `GET /api/v1/discover/movies/genre/{genreId}` | Movies by genre |
| `GET /api/v1/discover/tv/genre/{genreId}` | TV by genre |
| `GET /api/v1/discover/genreslider/movie` | Genre list with backdrop images |
| `GET /api/v1/discover/genreslider/tv` | Genre list with backdrop images |
| `GET /api/v1/movie/{tmdbId}` | Movie details + mediaInfo (availability) |
| `GET /api/v1/tv/{tmdbId}` | TV details + mediaInfo (availability) |
| `GET /api/v1/movie/{tmdbId}/similar` | Similar movies |
| `GET /api/v1/movie/{tmdbId}/recommendations` | Recommended movies |
| `GET /api/v1/tv/{tmdbId}/similar` | Similar TV shows |
| `GET /api/v1/tv/{tmdbId}/recommendations` | Recommended TV shows |
| `GET /api/v1/person/{personId}` | Person details |
| `GET /api/v1/person/{personId}/combined_credits` | Person filmography |
| `POST /api/v1/request` | Create media request `{ mediaType, mediaId }` |
| `GET /api/v1/request?take=X&skip=X` | List user's requests |
| `GET /api/v1/settings/about` | Connection test |
| `POST /api/v1/auth/local` | Username/password auth |

**MediaInfo status codes** (from `seerr-tv/lib/OverseerrClient/models/MediaInfo.ts`):
- 1 = UNKNOWN
- 2 = PENDING
- 3 = PROCESSING
- 4 = PARTIALLY_AVAILABLE
- 5 = AVAILABLE

### Trakt Endpoints Used

Requires app registration at `https://trakt.tv/oauth/applications` (redirect URI: `urn:ietf:wg:oauth:2.0:oob`).

| Endpoint | Purpose | Auth Required |
|----------|---------|---------------|
| `POST /oauth/device/code` | Start device code auth flow | No |
| `POST /oauth/device/token` | Poll for auth completion | No |
| `POST /oauth/token` | Refresh expired token | No |
| `GET /recommendations/movies?limit=X` | Personalized movie recs | Yes |
| `GET /recommendations/shows?limit=X` | Personalized show recs | Yes |
| `GET /movies/trending?page=X&limit=X` | Trending movies | No |
| `GET /shows/trending?page=X&limit=X` | Trending shows | No |
| `GET /movies/popular?page=X&limit=X` | Popular movies | No |
| `GET /shows/popular?page=X&limit=X` | Popular shows | No |
| `GET /sync/history/{type}?page=1&limit=5` | Recent watch history | Yes |
| `GET /genres/movies` | Movie genre list | No |
| `GET /genres/shows` | Show genre list | No |

All Trakt responses include `ids.tmdb` for cross-referencing with Overseerr.

Headers required: `Content-Type: application/json`, `trakt-api-version: 2`, `trakt-api-key: {client_id}`, `Authorization: Bearer {token}` (authenticated endpoints).

Rate limit: 1000 GET requests per 5 minutes.

---

## User Requirements

1. **Home screen sections:** Personalized recommendations, trending/popular, genre browsing
2. **Availability marking:** Show all content, visually badge items that are available/requested/pending
3. **Language filtering:** TMDB region-based filtering (pass `language` param to Overseerr endpoints)
4. **Request status:** Overseerr status only (pending/approved/available) - no Radarr/Sonarr pipeline
5. **Trakt is optional:** App works with Overseerr-only; Trakt unlocks personalization features

---

## Project Structure

```
Curator/
├── Curator.xcodeproj
├── Curator/
│   ├── App/
│   │   ├── CuratorApp.swift                 # @main entry, WindowGroup, environment setup
│   │   └── AppState.swift                   # @Observable: auth status for all services, shared clients
│   │
│   ├── Models/
│   │   ├── Trakt/
│   │   │   ├── TraktMovie.swift
│   │   │   ├── TraktShow.swift
│   │   │   ├── TraktGenre.swift
│   │   │   ├── TraktDeviceCode.swift
│   │   │   ├── TraktToken.swift
│   │   │   └── TraktHistoryItem.swift
│   │   ├── Overseerr/
│   │   │   ├── OverseerrMediaResult.swift   # Search/discover result
│   │   │   ├── OverseerrMediaInfo.swift     # Availability status (1-5)
│   │   │   ├── OverseerrMediaRequest.swift
│   │   │   ├── OverseerrMovieDetails.swift
│   │   │   ├── OverseerrTvDetails.swift
│   │   │   └── OverseerrUser.swift
│   │   └── MediaItem.swift                  # Unified display model (Trakt + Overseerr merged)
│   │
│   ├── Services/
│   │   ├── TraktClient.swift                # URLSession async/await, all Trakt endpoints
│   │   ├── TraktAuthManager.swift           # Device code flow, token storage/refresh
│   │   ├── OverseerrClient.swift            # URLSession async/await, all Overseerr endpoints
│   │   ├── MediaResolver.swift              # Cross-API orchestration (Trakt tmdb_id -> Overseerr details)
│   │   └── ImageService.swift               # TMDB image URL builder
│   │
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift              # Recommendations, trending, popular shelves
│   │   ├── GenreBrowseViewModel.swift       # Genre grid + filtered results
│   │   ├── SearchViewModel.swift            # Overseerr search
│   │   ├── DetailViewModel.swift            # Movie/TV detail + request action
│   │   └── SettingsViewModel.swift          # Service configuration
│   │
│   ├── Views/
│   │   ├── ContentView.swift                # Root TabView (Home, Browse, Search, Settings)
│   │   ├── Home/
│   │   │   ├── HomeView.swift               # Vertical scroll of horizontal shelves
│   │   │   └── RecommendationRow.swift      # "Because you watched X" shelf
│   │   ├── Browse/
│   │   │   ├── GenreListView.swift          # Grid of genre cards with backdrop images
│   │   │   └── GenreResultsView.swift       # Paginated grid for a genre
│   │   ├── Search/
│   │   │   └── SearchView.swift             # Text input + results grid
│   │   ├── Detail/
│   │   │   ├── MovieDetailView.swift        # Hero + metadata + request button + similar/recommended
│   │   │   ├── TVDetailView.swift
│   │   │   └── PersonDetailView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift           # Connection status overview
│   │   │   ├── OverseerrSetupView.swift     # Server URL, port, auth type, API key/credentials
│   │   │   └── TraktSetupView.swift         # Device code flow UI
│   │   └── Onboarding/
│   │       └── OnboardingView.swift         # First-launch wizard
│   │
│   ├── Components/
│   │   ├── MediaCard.swift                  # Poster card with .buttonStyle(.card) focus effects
│   │   ├── MediaCardWide.swift              # Backdrop-based wide card for featured content
│   │   ├── AvailabilityBadge.swift          # Green check / clock / partial overlay
│   │   ├── BackdropHeroView.swift           # Full-width backdrop hero with poster, metadata, action buttons (650pt, ~60% screen)
│   │   ├── FocusableCardButtonStyle.swift   # Custom tvOS focus card style
│   │   ├── StatusPill.swift                 # "Available" / "Requested" / "Pending" text pill
│   │   ├── MediaShelfView.swift             # Horizontal ScrollView + LazyHStack + .focusSection()
│   │   ├── ShelfHeaderView.swift            # Title + "See All" button
│   │   ├── DeviceCodeView.swift             # Shows Trakt code + URL prominently
│   │   ├── YouTubePlayerView.swift          # TrailerPlayer + AVPlayerViewController + YouTubeStreamExtractor (codec filtering, cascading quality, error UI)
│   │   ├── LoadingView.swift
│   │   └── ErrorView.swift                  # Error state with retry button
│   │
│   ├── Utilities/
│   │   ├── KeychainHelper.swift             # Thin wrapper around SecItemAdd/SecItemCopyMatching
│   │   ├── UserDefaultsKeys.swift           # Typed keys
│   │   └── Constants.swift                  # API base URLs, image sizes
│   │
│   └── Resources/
│       └── Assets.xcassets                  # App icon, colors
```

---

## Architecture: MVVM with @Observable

```
Views (SwiftUI) ──reads──> ViewModels (@Observable) ──calls──> Services (async/await)
                                                                    │
                                                              Models (Codable)
```

- **@Observable** (Swift 5.9+ macro) for all ViewModels - no Combine needed
- **NavigationStack** with `navigationDestination` for drill-down navigation
- **TabView** at root (auto-hides top bar on scroll - native tvOS behavior)
- **`.onExitCommand`** on non-Home tabs returns to Home; on Home, scrolls to top via `ScrollViewReader`
- **async/await** throughout - no callbacks, no Combine publishers
- All API clients are Swift `actor` types for thread safety

### Unified MediaItem Model

```swift
struct MediaItem: Identifiable, Hashable {
    let id: String              // "movie-{tmdbId}" or "tv-{tmdbId}"
    let tmdbId: Int
    let mediaType: MediaType    // .movie or .tv
    let title: String
    let year: Int?
    let overview: String?
    let posterPath: String?     // TMDB poster path
    let backdropPath: String?   // TMDB backdrop path
    let voteAverage: Double?
    var availability: AvailabilityStatus  // from Overseerr mediaInfo

    enum MediaType: String, Codable { case movie, tv }
    enum AvailabilityStatus {
        case unknown, available, partiallyAvailable, processing, pending, none
    }
}
```

### MediaResolver (Cross-API Orchestration)

For Trakt-sourced items:
1. Trakt returns titles with `ids.tmdb`
2. For each tmdb_id, call `OverseerrClient.getMovieDetails(tmdbId)` or `.getTvDetails(tmdbId)` — returns poster, backdrop, overview, AND mediaInfo (availability) in one call
3. Merge into `MediaItem` for display

This avoids needing a separate TMDB API key entirely.

---

## Screen Breakdown

### Tab 1: Home

Vertical scroll of horizontal shelves:

| Section | Data Source | API Calls |
|---------|-------------|-----------|
| "Because you watched [Title]" (x3) | Trakt history + Overseerr recs | Trakt: `GET /sync/history/movies?limit=3`, then Overseerr: `GET /movie/{tmdbId}/recommendations` per title |
| "Trending Movies" | Trakt (or Overseerr fallback) | Trakt: `GET /movies/trending?limit=20` -> resolve via Overseerr |
| "Trending Shows" | Trakt (or Overseerr fallback) | Trakt: `GET /shows/trending?limit=20` -> resolve via Overseerr |
| "Popular Movies" | Trakt (or Overseerr fallback) | Trakt: `GET /movies/popular?limit=20` -> resolve via Overseerr |
| "Popular Shows" | Trakt (or Overseerr fallback) | Trakt: `GET /shows/popular?limit=20` -> resolve via Overseerr |

**Fallback (no Trakt):** Use Overseerr endpoints: `/discover/trending`, `/discover/movies`, `/discover/tv`, `/discover/movies/upcoming`, `/discover/tv/upcoming`

Each shelf uses `MediaShelfView` with `.focusSection()` for proper tvOS up/down navigation between shelves.

### Tab 2: Browse (Genres)

- Genre grid using Overseerr's `GET /discover/genreslider/movie` and `/discover/genreslider/tv` (returns genre names + backdrop images for cards)
- Tap a genre -> `GenreResultsView` with paginated grid via `GET /discover/movies/genre/{id}` or `/discover/tv/genre/{id}` with `language` param for region filtering

### Tab 3: Search

- Text input (tvOS keyboard on focus)
- Debounced 500ms
- Overseerr `GET /search?query=X&page=X`
- Results grid with MediaCards, infinite scroll pagination

### Tab 4: Settings

Sections:
1. **Overseerr** — connection type (HTTP/HTTPS), server address, port, auth type (API key / user+pass), test/save/clear
2. **Trakt** — "Connect" button (device code flow) or "Connected as {username}" + "Disconnect"
3. **Region** — Language/region picker for filtering content

### Detail Screens (push navigation from any MediaCard)

**MovieDetailView / TVDetailView:**
- Hero: full-width backdrop + poster + title + year + runtime + genres
- Action buttons row: Trailer button + Request quality buttons (or StatusPill when requested/available)
- Trailer button opens YouTube app externally (in-app playback via yt-dlp backend planned for Phase 6)
- Overview text
- Cast/crew horizontal scroll
- "You Might Like" shelf (merged similar + recommended, genre-filtered)

**PersonDetailView:**
- Bio + filmography grid via Overseerr `/person/{id}/combined_credits`

### Onboarding (first launch)

1. Welcome screen
2. Overseerr setup (required) — must test connection successfully
3. Trakt setup (optional) — device code flow, "Skip" available
4. "Start exploring"

---

## Authentication Flows

### Overseerr (required)

**API Key mode:** User enters server URL + port + API key. Stored: Keychain (API key), UserDefaults (URL, port, connection type).
Validation: `GET /api/v1/settings/about` returns 200.

**User mode:** User enters URL + port + username + password. `POST /api/v1/auth/local` returns session cookie.

### Trakt (optional, recommended)

Device Code OAuth 2.0 — ideal for TV (no keyboard-heavy entry):
1. App calls `POST https://api.trakt.tv/oauth/device/code` with `{ "client_id": "..." }`
2. Response: `{ "device_code": "...", "user_code": "ABC123", "verification_url": "https://trakt.tv/activate", "interval": 5 }`
3. App displays: "Go to **trakt.tv/activate** and enter **ABC123**" (large monospaced text)
4. App polls `POST /oauth/device/token` every 5 seconds
5. On success: store `access_token` + `refresh_token` in Keychain
6. Token refresh via `POST /oauth/token` with `grant_type: refresh_token`

`client_id` and `client_secret` compiled into the app (acceptable for personal TestFlight).

### Storage Map

**Keychain:** `overseerr.apiKey`, `overseerr.password`, `trakt.accessToken`, `trakt.refreshToken`
**UserDefaults:** `overseerr.connectionType`, `overseerr.address`, `overseerr.port`, `overseerr.authType`, `overseerr.username`, `app.hasCompletedOnboarding`, `trakt.isConnected`

---

## Key tvOS SwiftUI Patterns

- **`.buttonStyle(.card)`** on MediaCard — provides native lift, scale, parallax, and shadow on focus
- **`.focusSection()`** on each shelf — enables proper up/down navigation between shelves, left/right within
- **`NavigationStack`** (not `NavigationSplitView`) — better for TV drill-down flows
- **`TabView`** at root — renders as auto-hiding top bar (native tvOS)
- **`AsyncImage`** for poster/backdrop loading with system URL cache
- **No Kingfisher/Nuke** — AsyncImage is sufficient for single-user app

---

## Implementation Phases (sequencing only, no time estimates)

### Phase 1: Project Setup & Foundation -- COMPLETE
1. ~~Create Xcode tvOS project (SwiftUI lifecycle, tvOS 17 deployment target)~~ -- Used xcodegen
2. ~~Set up folder structure per the tree above~~
3. ~~Implement `Constants.swift`, `KeychainHelper.swift`, `UserDefaultsKeys.swift`~~
4. ~~Define all Codable model structs~~

### Phase 2: Overseerr Integration -- COMPLETE
5. ~~Implement `OverseerrClient` (URLSession, all endpoints listed above)~~
6. ~~Implement `AppState` with Overseerr connection management~~
7. ~~Build `SettingsView` + `OverseerrSetupView` (config, test, save)~~
8. ~~Build `OnboardingView` (Overseerr-only flow)~~
9. ~~Build `SearchView` + `SearchViewModel`~~
10. ~~Build `MediaCard` + `AvailabilityBadge` components~~
11. ~~Build `MovieDetailView` + `TVDetailView` + `DetailViewModel` (details + request button)~~

**Milestone:** Functioning Overseerr client comparable to existing seerr-tv app. ACHIEVED

### Phase 3: Discovery UI (Overseerr Fallback) -- COMPLETE
12. ~~Build `MediaShelfView` + `ShelfHeaderView`~~
13. ~~Build `HomeView` + `HomeViewModel` with Overseerr discover endpoints~~
14. ~~Build `GenreListView` + `GenreResultsView` + `GenreBrowseViewModel` using Overseerr genre endpoints~~
15. ~~Build root `ContentView` TabView navigation~~
16. "See All" paginated grid views -- DEFERRED to Phase 5 (shelves currently show full results inline)

**Milestone:** Full browsing app with Overseerr-powered discovery. ACHIEVED

### Phase 4: Trakt Integration -- COMPLETE
17. ~~Register Trakt API application at trakt.tv~~ -- Credentials in .env.local
18. ~~Implement `TraktClient` (all endpoints listed above)~~
19. ~~Implement `TraktAuthManager` with device code flow~~
20. ~~Build `TraktSetupView` + `DeviceCodeView`~~
21. ~~Implement `MediaResolver` (Trakt tmdb_id -> Overseerr detail+availability)~~
22. ~~Update `HomeViewModel` to prefer Trakt data when connected~~
23. ~~Build "Because you watched X" recommendation shelves~~

**Milestone:** Personalized discovery powered by Trakt watch history. ACHIEVED

### Phase 5: Polish -- IN PROGRESS
24. ~~`PersonDetailView`~~ -- COMPLETE
25. ~~Error handling views with retry~~ -- `ErrorView` component built in Phase 2
26. ~~Loading states throughout~~ -- `LoadingView` component built in Phase 2
27. ~~Focus navigation refinement~~ -- `.onExitCommand` returns non-Home tabs to Home, Home scrolls to top
28. ~~App icon~~ -- Custom icon with improved cropping
29. TestFlight build and distribution
30. "See All" paginated grid views (deferred from Phase 3)
31. Trailer playback -- Currently opens YouTube app externally. In-app playback via yt-dlp backend planned (see Phase 6)
32. ~~Status pill placement~~ -- Moved inline with hero action buttons (replaces request buttons when status active)

### Phase 6: Future Opportunities
33. Trakt user custom lists and watchlist integration
34. Requests tab — view/manage submitted requests with status tracking
35. Region/language picker in Settings for content filtering
36. Deep link support (Siri, URL schemes)
37. Background refresh for request status polling
38. In-app trailer playback via yt-dlp backend — Spin up a lightweight web server (e.g. FastAPI + yt-dlp) that resolves YouTube stream URLs on demand. The app calls the server to get a direct MP4 URL, then plays it with AVPlayer. Pre-fetch the stream URL on detail view load (resolution takes 5-10s) and cache results in memory (~6hr TTL) so playback is instant when the user taps "Trailer". WKWebView is NOT available on tvOS, so embedded YouTube iframes are not an option. Client-side innertube extraction was removed due to persistent bot detection, auth failures, and codec issues
39. Scroll position restoration when returning from detail views
40. Top Shelf Image assets for Apple TV home screen

---

## Reference Files (from existing seerr-tv codebase)

These files in `~/playground/seerr-tv/` contain patterns and API details to reference during development:

| File | What to reference |
|------|-------------------|
| `lib/OverseerrClient/services/SearchService.ts` | All Overseerr discover/search endpoint signatures and parameters |
| `lib/OverseerrClient/services/RequestService.ts` | Request creation API shape |
| `lib/OverseerrClient/services/MoviesService.ts` | Movie detail + similar + recommendations endpoints |
| `lib/OverseerrClient/services/TvService.ts` | TV detail endpoints |
| `lib/OverseerrClient/models/MediaInfo.ts` | Availability status codes (1-5) |
| `lib/OverseerrClient/models/MovieResult.ts` | Search/discover result shape (includes posterPath, mediaInfo) |
| `lib/OverseerrClient/models/TvResult.ts` | TV result shape |
| `lib/OverseerrClient/models/MediaRequest.ts` | Request model shape |
| `lib/store.ts` | Auth patterns (API key header vs user/pass), client instantiation |
| `lib/constants.ts` | TMDB image URL format, default port (5055), connection defaults |
| `app/(tabs)/index.tsx` | Home screen shelf layout and data fetching pattern |
| `app/(tabs)/search.tsx` | Search implementation with debounce and infinite scroll |
| `app/(tabs)/settings.tsx` | Settings UI and connection testing flow |
| `app/movie/[id].tsx` | Movie detail screen layout and request flow |
| `app/tv/[id].tsx` | TV detail screen and season request pattern |
| `lib/movieGenres.json` | Static genre ID -> name mapping |
| `lib/tvGenres.json` | Static TV genre mapping |

---

## Prerequisites Before Starting Development on Mac

1. **Xcode 15+** with tvOS 17 SDK installed
2. **Apple Developer account** (for TestFlight distribution)
3. **Register Trakt API app** at `https://trakt.tv/oauth/applications` — redirect URI: `urn:ietf:wg:oauth:2.0:oob`
4. **Overseerr instance** running and accessible (user already has this)
5. **Clone this repo** and reference the plan + seerr-tv codebase for API details
