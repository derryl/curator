# Curator - Future TODOs

## App Icon

- [ ] Add Top Shelf Image assets (1920x720 @1x/@2x) — currently stubbed with empty slots
- [ ] Add Top Shelf Image Wide assets (2320x720 @1x/@2x) — currently stubbed with empty slots
- [ ] Consider adding parallax effect by separating film reel (Front) from glow/sparkles (Middle) and background gradient (Back) into distinct layers

## TV Detail View

- [ ] Apply same hero redesign as MovieDetailView (action buttons below title, trailer button, edge-to-edge hero)
- [ ] TV shows also have `relatedVideos` in the Overseerr API — add trailer support to TVDetailView
- [ ] Add "You Might Like" merged section (currently still has separate Similar/Recommended sections)

## Trailer Playback

- [ ] `youtube://` deep link only works when YouTube app is installed; on simulator or devices without YouTube, user sees an alert
- [ ] Consider alternative: embed a WKWebView with YouTube iframe player as a fallback
- [ ] Test trailer functionality on a real Apple TV device with YouTube installed

## Trakt Integration (from research plan)

- [ ] Implement Trakt user custom list fetching (`/users/{id}/lists/{list_id}/items/{type}`)
- [ ] Implement Trakt watchlist fetching (`/users/me/watchlist/{type}`)
- [ ] Add `TraktListItem` model (rank, id, listedAt, notes, type, movie, show)
- [ ] Add `tvdb: Int?` to `TraktIds` model for show support
- [ ] See detailed API research in plan file: `frolicking-growing-pnueli-agent-aaf0794984dc2181d.md`

## Code Quality

- [ ] Remove debug `print("[Curator] relatedVideos decode failed:")` from OverseerrMovieDetails.swift (currently in do/catch, low priority)
- [ ] Consider adding `relatedVideos` support to `OverseerrTvDetails` model as well

## Known Behaviors

- tvOS simulator icon cache is aggressive — after changing icons, must do: clean build + uninstall app + reboot simulator + reinstall
- The `com.derryl.curator` bundle ID is lowercase (not `com.derryl.Curator`)
- `print()` doesn't appear in unified log on Apple platforms; use `NSLog` or `os.Logger` for debugging
