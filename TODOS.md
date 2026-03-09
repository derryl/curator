## Running list of user todo's

### In-app Trailer Playback (yt-dlp backend + VLCKit)

Implement in-app trailer playback using a hosted yt-dlp service and TVVLCKit on the client.

Backend: lightweight HTTP service running `yt-dlp` that resolves YouTube URLs to direct stream URLs (highest quality available, no transcoding). Hosted on the media server alongside Overseerr.

Client: TVVLCKit streams whatever format the backend returns (VP9/WebM up to 4K, H.264, etc.) directly — no format restrictions.

Feasibility confirmed on `feat/vlckit-feasibility` branch — VLCKit builds for tvOS and plays VP9 WebM including 4K. See PLAN.md Phase 6 item 38 for full architecture details.

Next steps:
- Build and deploy the yt-dlp resolver service
- Integrate VLCPlayerView into detail views (replace external YouTube app launch)
- Pre-fetch stream URL on detail view load for instant playback
- Test on physical Apple TV hardware (simulator has expected framerate limitations)

### Exploration: "Browse" Genres

Up next: tweak and refine quality filter settings, and potentially incorporate Trakt personalization to augment genre grid results.

===============================================

#### Finished todo's

- [x] example finished todo
- [x] Simplify request to single [Request] button using Overseerr defaults
- [x] Fix navigation BACK button to properly reverse the stack
- [x] Fix YouTube trailer 720p quality cap (Range GET validation)
- [x] Fix YouTube intermittent auth errors (client version update + retry)
- [x] Fix BACK button on Top Nav minimizing app (now navigates to Home)
- [x] Fix tab navigation state persisting across tab switches (now resets on leave)
- [x] Switch genre discovery to TMDB-backed base endpoint with quality filters (voteAvg≥6.5, voteCount≥200)
- [x] Interleave recent well-reviewed releases near top of genre grids for freshness
- [x] Add comprehensive genre discovery tests (19 tests covering endpoints, interleave, pagination, errors)
- [x] Fix missing year on movie/TV detail views (fall back to detail model's releaseDate/firstAirDate)
- [x] Fix backdrop image positioning on detail views (top-align to avoid nav bar occlusion)
