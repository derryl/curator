# Curator - Future TODOs

## App Icon

- [ ] Add Top Shelf Image assets (1920x720 @1x/@2x) — currently stubbed with empty slots
- [ ] Add Top Shelf Image Wide assets (2320x720 @1x/@2x) — currently stubbed with empty slots
- [ ] Consider adding parallax effect by separating film reel (Front) from glow/sparkles (Middle) and background gradient (Back) into distinct layers

## TV Detail View

- [x] Apply same hero redesign as MovieDetailView (action buttons below title, trailer button, edge-to-edge hero) — done in `e4c340c`
- [x] TV shows also have `relatedVideos` in the Overseerr API — added trailer support to TVDetailView — done in `e4c340c`
- [x] Add "You Might Like" merged section with genre filtering — done in `e4c340c`

## Trailer Playback

- [x] Removed `youtube://` deep link that required YouTube app to be installed
- [x] Added `TrailerSheet` with `AVPlayerViewController` for native tvOS playback
- [x] `.fullScreenCover(item:)` presents/dismisses correctly on Apple TV (uses `TrailerVideo: Identifiable` wrapper to avoid stale-state bug with `isPresented:` variant)
- [x] **Fixed YouTube stream extraction** — replaced HTML-scraping approach (HLS URLs required auth headers) with innertube API using ANDROID client identity. Returns progressive MP4 URLs that `AVPlayer` plays directly. HTML scraping retained as fallback. — done in `1e8b2ac`
- [x] **External fallback** — when all extraction strategies fail, opens YouTube app externally instead of showing empty player — done in `1e8b2ac`
- [x] **Max quality playback** — upgraded from progressive formats (720p max) to adaptive formats (1080p+) using separate video+audio streams composed via `AVMutableComposition`. `StreamResult` carries both URLs; `TrailerPlayer` composes them at playback time. Falls back to progressive if adaptive unavailable. — done in `4fc0eb5`
- [x] **Codec filtering** — filter adaptive formats to tvOS-compatible codecs only (H.264/H.265 video in mp4, AAC audio in mp4). VP9, AV1, and Opus are rejected, preventing silent playback failures and potential video signal loss on Apple TV. — done in `d4a0206`
- [x] **Cascading quality fallback** — when 1080p adaptive URL returns 403, try 720p adaptive before dropping to progressive. Previously jumped directly to 720p progressive. — done in `d4a0206`
- [x] **Audio URL validation** — validate both video AND audio URLs via HEAD request. Previously only video was validated; broken audio caused composition failure with silent video-only fallback. — done in `d4a0206`
- [x] **TrailerError enum** — typed errors (ageRestricted, videoUnavailable, allStreamsBroken, networkError, compositionFailed, playbackTimeout) with user-facing messages. Previously all errors were swallowed as nil with no diagnostics. — done in `d4a0206`
- [x] **Error UI** — show error alert with specific message and "Open in YouTube" fallback button on both MovieDetailView and TVDetailView. Previously silently opened YouTube externally on failure. — done in `d4a0206`
- [x] **PiP disabled** — `allowsPictureInPicturePlayback = false` on player VC for cleaner dismiss behavior. — done in `d4a0206`
- [x] **Dolby Vision fix** — `appliesPreferredDisplayCriteriaAutomatically = false` prevents DV-to-SDR mode switch during trailer playback, eliminating ~1-2s black screen flash on enter/exit. — done in `e9f1872`
- [x] **Live integration tests** — 11 tests hitting real YouTube servers to verify stream extraction, quality, URL accessibility, error handling, codec safety, and batch reliability. — done in `8982440`
- [x] **Unit tests** — 25 tests covering codec filtering, cascading quality, audio validation, all error types, user messages, HLS preference, and empty data handling — done in `d4a0206`
- [ ] Multiple BACK presses needed to dismiss the trailer player — `AVPlayerViewController` intercepts the Menu button for its own transport bar before the `.fullScreenCover` dismisses. PiP disabled in `d4a0206` which helps but may not fully resolve on all tvOS versions. Consider implementing a custom lightweight player view (no transport bar) that dismisses on first Menu press.

## Navigation

- [x] **BACK to Home** — pressing Menu on non-Home tabs (Browse, Search, Settings) returns to Home instead of exiting the app, via `.onExitCommand`. — done in `3e36aa6`
- [x] **Scroll to top on Home** — pressing Menu on Home tab scrolls to top of the feed via `ScrollViewReader`. — done in `3e36aa6`
- [ ] Consider implementing scroll position restoration when returning to a screen (e.g. returning from detail to a shelf should preserve horizontal scroll position)

## Status Pill / Request UI

- [x] **Moved StatusPill into hero** — status pill (Processing, Requested, Available) now appears in the hero action buttons area inline with the Trailer button, replacing request buttons when status is active. Removed standalone section below hero. — done in `3e36aa6`
- [x] **Unit tests** — 7 tests for StatusPill config logic and hero button display rules. — done in `3e36aa6`

## Trakt Integration (from research plan)

- [ ] Implement Trakt user custom list fetching (`/users/{id}/lists/{list_id}/items/{type}`)
- [ ] Implement Trakt watchlist fetching (`/users/me/watchlist/{type}`)
- [ ] Add `TraktListItem` model (rank, id, listedAt, notes, type, movie, show)
- [ ] Add `tvdb: Int?` to `TraktIds` model for show support
- [ ] API endpoints: `/users/{id}/lists/{list_id}/items/{type}`, `/users/me/watchlist/{type}`

## Future Opportunities

- [ ] "See All" paginated grid views for shelves (deferred from Phase 3)
- [ ] Region/language picker in Settings for filtered content discovery
- [ ] Requests tab — view and manage submitted requests with status tracking
- [ ] Deep link support — open specific titles from Siri, notifications, or URL schemes
- [ ] Background refresh — periodic polling for request status changes with silent notifications
- [ ] Custom lightweight trailer player — avoid AVPlayerViewController transport bar entirely for single-press Menu dismiss; could also allow custom quality indicator overlay

## Code Quality

- [x] `relatedVideos` support added to `OverseerrTvDetails` — done in `e4c340c`

## Known Behaviors

- tvOS simulator icon cache is aggressive — after changing icons, must do: clean build + uninstall app + reboot simulator + reinstall
- The `com.derryl.curator` bundle ID is lowercase (not `com.derryl.Curator`)
- `print()` doesn't appear in unified log on Apple platforms; use `NSLog` or `os.Logger` for debugging

## Test Coverage Summary

| Test Suite | Count | Type |
|---|---|---|
| YouTubeStreamExtractorTests | 25 | Unit (mocked network) |
| YouTubeLiveIntegrationTests | 11 | Integration (live YouTube) |
| StatusPillPlacementTests | 7 | Unit |
| QualityOptionTests | 7 | Unit |
| DetailViewModelTests | 6 | Unit (mocked network) |
| OverseerrClientTests | 6 | Unit (mocked network) |
| NavigationTests | 6 | UI (live simulator) |
| ContentLoadingTests | 2 | UI (live simulator) |
| ScreenshotTests | 4 | UI (live simulator) |
| **Total** | **74** | |
