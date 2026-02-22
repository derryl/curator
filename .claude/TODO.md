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
- [x] **Max quality playback** — upgraded from progressive formats (720p max) to adaptive formats (1080p+) using separate video+audio streams composed via `AVMutableComposition`. `StreamResult` carries both URLs; `TrailerSheet` composes them at playback time. Falls back to progressive if adaptive unavailable. — done in `4fc0eb5`
- [x] **Unit tests** — 12 tests for `YouTubeStreamExtractor` covering adaptive format preference, resolution/bitrate selection, progressive fallback, innertube request format, response parsing, fallback chain, and error handling — done in `4fc0eb5`
- [ ] Multiple BACK presses needed to dismiss the trailer player — `AVPlayerViewController` intercepts the Menu button for its own transport bar before the `.fullScreenCover` dismisses

## Trakt Integration (from research plan)

- [ ] Implement Trakt user custom list fetching (`/users/{id}/lists/{list_id}/items/{type}`)
- [ ] Implement Trakt watchlist fetching (`/users/me/watchlist/{type}`)
- [ ] Add `TraktListItem` model (rank, id, listedAt, notes, type, movie, show)
- [ ] Add `tvdb: Int?` to `TraktIds` model for show support
- [ ] API endpoints: `/users/{id}/lists/{list_id}/items/{type}`, `/users/me/watchlist/{type}`

## Code Quality

- [x] `relatedVideos` support added to `OverseerrTvDetails` — done in `e4c340c`

## Known Behaviors

- tvOS simulator icon cache is aggressive — after changing icons, must do: clean build + uninstall app + reboot simulator + reinstall
- The `com.derryl.curator` bundle ID is lowercase (not `com.derryl.Curator`)
- `print()` doesn't appear in unified log on Apple platforms; use `NSLog` or `os.Logger` for debugging
