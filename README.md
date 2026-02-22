# Curator

A tvOS app for discovering and requesting movies and TV shows through [Overseerr](https://overseerr.dev/), with optional [Trakt](https://trakt.tv/) integration for personalized recommendations.

## Features

- Browse trending, popular, and upcoming content
- Search across your Overseerr library
- Browse by genre with category filtering
- View detailed movie/TV info including cast, similar titles, and recommendations
- Request unavailable content with quality profile selection (Radarr/Sonarr)
- Watch trailers inline with max-quality adaptive streaming
- Trakt integration for personalized recommendations via OAuth device code flow
- Fully native tvOS UI optimized for the Apple TV remote

## Requirements

- tvOS 17.0+
- An [Overseerr](https://overseerr.dev/) instance with API access
- (Optional) A [Trakt](https://trakt.tv/) account for recommendations

## Building

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Curator.xcodeproj
```

Build and run on an Apple TV simulator or device from Xcode.

## Project Structure

```
Curator/
  App/              App entry point and global state
  Components/       Reusable UI components (hero view, media cards, trailer player)
  Models/           Data models for Overseerr and Trakt APIs
  Services/         API clients (OverseerrClient, TraktClient, ImageService)
  Utilities/        Keychain helper, constants, UserDefaults keys
  ViewModels/       View models for each screen
  Views/            SwiftUI views organized by feature
CuratorTests/       Unit tests with MockURLProtocol-based network mocking
CuratorUITests/     UI tests for navigation, content loading, and screenshots
```

## Configuration

On first launch, the onboarding flow guides you through connecting to Overseerr (URL + API key) and optionally linking your Trakt account. Credentials are stored in the Keychain.

## Testing

```bash
# Run unit tests
xcodebuild test -project Curator.xcodeproj -scheme CuratorTests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'

# Run UI tests
xcodebuild test -project Curator.xcodeproj -scheme CuratorUITests \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'
```

## Tech Stack

- Swift 6 / SwiftUI
- AVKit (trailer playback with adaptive stream composition)
- Async/await concurrency with actor-based API clients
- XcodeGen for project generation
- No external dependencies
