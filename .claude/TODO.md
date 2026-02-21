# Curator - Future TODOs

## App Icon

- [ ] Add Top Shelf Image assets (1920x720 @1x/@2x) — currently stubbed with empty slots
- [ ] Add Top Shelf Image Wide assets (2320x720 @1x/@2x) — currently stubbed with empty slots
- [ ] Consider adding parallax effect by separating film reel (Front) from glow/sparkles (Middle) and background gradient (Back) into distinct layers

## TV Detail View

- [x] Apply same hero redesign as MovieDetailView (action buttons below title, trailer button, edge-to-edge hero) — done in `e4c340c`
- [x] TV shows also have `relatedVideos` in the Overseerr API — added trailer support to TVDetailView — done in `e4c340c`
- [x] Add "You Might Like" merged section with genre filtering — done in `e4c340c`

## Trailer Playback (In Progress)

Inline trailer player added but YouTube stream extraction is not yet producing playable content. Current state:

- [x] Removed `youtube://` deep link that required YouTube app to be installed
- [x] Added `TrailerSheet` with `AVPlayerViewController` for native tvOS playback
- [x] Added `YouTubeStreamExtractor` with two strategies: regex-based HLS URL extraction from watch page HTML, and full `ytInitialPlayerResponse` JSON parsing as fallback
- [x] `.fullScreenCover(item:)` presents/dismisses correctly on Apple TV (uses `TrailerVideo: Identifiable` wrapper to avoid stale-state bug with `isPresented:` variant)
- [ ] **YouTube HLS streams not playing** — the extractor successfully finds an `hlsManifestUrl` from the watch page, and `AVPlayerViewController` presents with a scrub bar, but no video content actually plays. The HLS manifest URLs may be short-lived or require specific request headers/cookies that `AVPlayer` doesn't send. Needs investigation:
  - Try setting `AVURLAsset` options with custom HTTP headers
  - Check if the HLS manifest requires the same cookies/user-agent used to fetch the watch page
  - Consider extracting progressive format URLs instead (but most have `signatureCipher` requiring decryption)
  - WebKit/WKWebView is NOT available on tvOS — cannot use YouTube iframe embed
  - The innertube API with `TVHTML5_SIMPLY_EMBEDDED_PLAYER` and `IOS` client types both return errors without authentication
- [ ] Multiple BACK presses needed to dismiss the trailer player — `AVPlayerViewController` intercepts the Menu button for its own transport bar before the `.fullScreenCover` dismisses

## Trakt Integration (from research plan)

- [ ] Implement Trakt user custom list fetching (`/users/{id}/lists/{list_id}/items/{type}`)
- [ ] Implement Trakt watchlist fetching (`/users/me/watchlist/{type}`)
- [ ] Add `TraktListItem` model (rank, id, listedAt, notes, type, movie, show)
- [ ] Add `tvdb: Int?` to `TraktIds` model for show support
- [ ] See detailed API research in plan file: `frolicking-growing-pnueli-agent-aaf0794984dc2181d.md`

## Code Quality

- [x] `relatedVideos` support added to `OverseerrTvDetails` — done in `e4c340c`

## Known Behaviors

- tvOS simulator icon cache is aggressive — after changing icons, must do: clean build + uninstall app + reboot simulator + reinstall
- The `com.derryl.curator` bundle ID is lowercase (not `com.derryl.Curator`)
- `print()` doesn't appear in unified log on Apple platforms; use `NSLog` or `os.Logger` for debugging
