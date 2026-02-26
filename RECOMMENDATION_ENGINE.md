# Recommendation Engine Overhaul

Strategy and implementation tracker for transforming Curator into a powerful discovery engine by exploiting untapped API data, adding new discovery dimensions beyond genre, and deepening personalization.

## Architecture

All recommendations flow through:

- **TraktClient** — watch history, trending, anticipated, most-watched, ML recommendations
- **OverseerrClient** — TMDB details, credits, keywords, discover endpoints, availability
- **MediaResolver** — bridges Trakt items to Overseerr-enriched `MediaItem` objects
- **HomeViewModel** — orchestrates shelf loading, deduplication, and derived shelves
- **DetailViewModel** — per-title enrichment (director/actor shelves, keywords, collections)

## Phase 1: Quick Wins (reuse existing data)

### 1. Availability-prioritized sorting within shelves

Sort recommendation shelf items by actionability: requestable items first, then partially available, then pending/processing, then already available.

- [x] Add `requestPriority` computed property to `AvailabilityStatus`
- [x] Add `sortByRequestPriority()` static method to `HomeViewModel`
- [x] Apply to all recommendation shelf sources
- [x] Tests: `AvailabilityPriorityTests` (8 tests)

### 2. Top Rated home shelves

Derive "Top Rated Movies" and "Top Rated Shows" from existing popular/trending/upcoming data — no new API calls.

- [x] Add `topRatedMovies` / `topRatedShows` properties to `HomeViewModel`
- [x] Add `deriveTopRatedShelves()` method (filter >= 7.5, sort by rating, cap at 15)
- [x] Integrate into `deduplicateShelves()` pipeline
- [x] Add shelf sections to `HomeView`
- [x] Tests: `TopRatedShelfTests` (7 tests)

### 3. "More from Director" and "More with Lead Actor" shelves on detail pages

Leverage credits data already fetched on every detail page. Call `personCombinedCredits` for the director (movies) / executive producer (TV) and first-billed cast member.

- [x] Add `directorShelf` and `leadActorShelf` properties to `DetailViewModel`
- [x] Add `loadPersonShelves()` method with concurrent fetch
- [x] Add static `mediaItemFrom(credit:)` / `mediaItemFrom(crewCredit:)` helpers
- [x] Add shelf sections to `MovieDetailView` and `TVDetailView`
- [x] Fix existing `DetailViewModelTests` for new person credits requests
- [x] Tests: `PersonShelfTests` (10 tests)

## Phase 2: New Discovery Dimensions (new API calls, new views)

### 4. Trakt "Most Anticipated" and "Most Watched This Week" shelves

New Trakt endpoints providing fundamentally different signals from trending.

- [x] Add `TraktAnticipatedMovie` / `TraktAnticipatedShow` models
- [x] Add `TraktMostWatchedMovie` / `TraktMostWatchedShow` models
- [x] Add 4 new `TraktClient` methods: `anticipatedMovies/Shows`, `mostWatchedMovies/Shows`
- [x] Add fetch methods and shelf properties to `HomeViewModel`
- [x] Integrate into `loadTraktContent()` and `deduplicateShelves()`
- [x] Add shelf sections to `HomeView`
- [x] Tests: `TraktModelsTests` (6 tests)

### 5. Hidden Gems shelf

Surface well-rated but lesser-known titles from recommendations that don't appear in trending/popular.

- [x] Add `hiddenGems` property to `HomeViewModel`
- [x] Add `deriveHiddenGems()` method (exclude mainstream, filter >= 7.0, sort by rating, cap 15)
- [x] Add shelf section to `HomeView`
- [x] Tests: `HiddenGemsTests` (8 tests)

### 6. TMDB Keyword / Tag Discovery

Decode TMDB keywords from movie and TV details, render as tappable pills, and enable keyword-based browsing.

- [x] Add `OverseerrKeyword` and `OverseerrKeywordsWrapper` models
- [x] Add `keywords` field to `OverseerrMovieDetails` with custom decoder
- [x] Add `keywords` field to `OverseerrTvDetails` with custom decoder
- [x] Add custom encoders for both detail types
- [x] Add `discoverMoviesByKeyword` / `discoverTvByKeyword` to `OverseerrClient`
- [x] Add `KeywordBrowseViewModel` (paginated results loader)
- [x] Add `KeywordResultsView` with `KeywordDestination` navigation
- [x] Add keyword tag pills to `MovieDetailView` and `TVDetailView`
- [x] Register `KeywordDestination` navigation in `HomeView`, `GenreListView`, `SearchView`
- [x] Add to Xcode project (app + test targets)
- [x] Tests: `KeywordDiscoveryTests` (15 tests)

### 7. Collection / Franchise Grouping

Decode TMDB `belongs_to_collection` from movie details, fetch collection members, show "In This Collection" shelf.

- [ ] Add `OverseerrCollection` model (`id`, `name`, `posterPath`, `backdropPath`)
- [ ] Add `collection` field to `OverseerrMovieDetails` with custom decoding for `belongs_to_collection`
- [ ] Add `collection(collectionId:)` endpoint to `OverseerrClient`
- [ ] Add `collectionItems` property to `DetailViewModel`
- [ ] Add "In This Collection" shelf section to `MovieDetailView`
- [ ] Tests for collection decoding, endpoint, and view model

### 8. Person-Affinity Home Shelves ("You seem to love [Director/Actor]")

Detect recurring people in watch history and surface their other work as home shelves.

- [ ] Add `fetchPersonAffinityShelves()` to `HomeViewModel`
- [ ] Analyze first 20 watched movie details for recurring directors/cast (count >= 3)
- [ ] Fetch combined credits for top 1-2 people, filter out watched titles
- [ ] Create "Because you love [Name]'s work" shelves
- [ ] Cache person affinity results with weekly TTL in UserDefaults
- [ ] Tests for affinity detection, caching, and shelf construction

### 9. Decade Browsing

Add "By Decade" facet to the Browse tab alongside genres.

- [ ] Verify/add year-range discover methods to `OverseerrClient`
- [ ] Add `DecadeListView` (grid of decade cards)
- [ ] Add `DecadeResultsView` (paginated grid)
- [ ] Add decade facet to `GenreListView` (segmented picker or new section)
- [ ] Predefined decades: 1970s–2020s
- [ ] Tests for decade discover endpoints and view models

## Phase 3: Advanced Personalization

### 10. "Not in Your Library" Global Filter

Toggle that filters ALL shelves to show only items with `.availability == .none`.

- [ ] Add persisted `showOnlyRequestable: Bool` to `AppState`
- [ ] Apply filter in `HomeViewModel`, `GenreBrowseViewModel`, `SearchViewModel`
- [ ] Add toggle to Settings or home screen toolbar
- [ ] Tests for filter application across view models

### 11. Taste Profile Engine

Persistent, cached analysis of viewing patterns that powers multiple features.

- [ ] Create `TasteProfileEngine` actor
- [ ] Analyze last 50–100 watched items: credits + genres via Overseerr
- [ ] Build normalized affinity scores: genre, director, actor, decade
- [ ] Persist as JSON with weekly refresh
- [ ] Expose `scoreItem(_:against:) -> Double` for ranking candidates
- [ ] Tests for scoring, persistence, and refresh logic

### 12. "Complete the Franchise" Shelf

Cross-reference watch history with TMDB collections to find partially-watched franchises.

- [ ] Identify watched movies belonging to collections (depends on item 7)
- [ ] Find collections with partial completion
- [ ] Sort by completion percentage (highest first)
- [ ] Display as "Continue: [Collection Name]" home shelf
- [ ] Tests for franchise detection and completion sorting

### 13. Mood/Vibe-Based Browsing

Predefined "mood recipes" combining genre IDs + keyword IDs + rating filters.

- [ ] Define mood recipes: "Edge of Your Seat", "Feel-Good", "Mind-Bending", "True Stories", "Binge-Worthy"
- [ ] Combine genre + keyword discover calls (depends on item 6)
- [ ] Add as third Browse tab facet (Genres / Moods / Decades)
- [ ] Tests for mood recipe resolution and result merging

## Test Coverage Summary

| Test File | Tests | Status |
|-----------|-------|--------|
| AvailabilityPriorityTests | 8 | Passing |
| TopRatedShelfTests | 7 | Passing |
| PersonShelfTests | 10 | Passing |
| TraktModelsTests | 6 | Passing |
| HiddenGemsTests | 8 | Passing |
| KeywordDiscoveryTests | 15 | Passing |
| **Total new tests** | **54** | **All passing** |

## Implementation Sequence

Recommended order based on dependencies and value:

1. ~~Phase 1 (items 1–3)~~ — Done
2. ~~Items 4–5 (Trakt shelves + Hidden Gems)~~ — Done
3. ~~Item 6 (Keyword discovery)~~ — Done
4. Item 7 (Collection grouping) — Foundation for item 12
5. Item 8 (Person-affinity shelves) — API-heavy, needs caching
6. Item 9 (Decade browsing) — New browse facet
7. Item 10 ("Not in Library" toggle) — Simple filter, high utility
8. Item 11 (Taste Profile Engine) — Foundation for advanced features
9. Item 12 (Franchise completion) — Depends on item 7
10. Item 13 (Mood browsing) — Depends on item 6

## Key Files Modified

| File | Changes |
|------|---------|
| `Curator/Models/MediaItem.swift` | `requestPriority` on `AvailabilityStatus` |
| `Curator/ViewModels/HomeViewModel.swift` | New shelves, sorting, deduplication |
| `Curator/ViewModels/DetailViewModel.swift` | Director/actor shelves, person credits |
| `Curator/Services/TraktClient.swift` | Anticipated, most-watched endpoints |
| `Curator/Services/OverseerrClient.swift` | Keyword discover endpoints |
| `Curator/Models/Overseerr/OverseerrMovieDetails.swift` | Keywords field + custom codec |
| `Curator/Models/Overseerr/OverseerrTvDetails.swift` | Keywords field + custom codec |
| `Curator/Models/Overseerr/OverseerrKeyword.swift` | New model + wrapper |
| `Curator/Models/Trakt/TraktAnticipated.swift` | New models |
| `Curator/Models/Trakt/TraktMostWatched.swift` | New models |
| `Curator/ViewModels/KeywordBrowseViewModel.swift` | Keyword results loader |
| `Curator/Views/Browse/KeywordResultsView.swift` | Keyword results grid + destination |
| `Curator/Views/Detail/MovieDetailView.swift` | Keyword tags, director/actor shelves |
| `Curator/Views/Detail/TVDetailView.swift` | Keyword tags, director/actor shelves |
| `Curator/Views/Home/HomeView.swift` | All new shelf sections |
| `Curator/Views/Browse/GenreListView.swift` | Keyword navigation destination |
| `Curator/Views/Search/SearchView.swift` | Keyword navigation destination |
