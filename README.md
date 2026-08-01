# SeerrPlay

SeerrPlay combines Seerr discovery and requests with direct playback from the
user's own media server.

## Applications

- `apps/seerrplay`: Flutter for Android, Android TV, iPhone, iPad, macOS, and Windows.
- `apps/seerrplay_tvos`: native SwiftUI/AVKit application for Apple TV.

SeerrPlay detects the media server configured in Seerr and supports Plex,
Jellyfin, and Emby without resynchronizing already indexed libraries.

## Architecture

Implementation boundaries and dependency rules are documented in
[`docs/architecture.md`](docs/architecture.md). Proposed Seerr improvements are
tracked in [`docs/seerr-upstream-roadmap.md`](docs/seerr-upstream-roadmap.md).

## Development

```sh
cd apps/seerrplay
flutter pub get
flutter analyze
flutter test
```

The Apple TV project is generated with XcodeGen:

```sh
cd apps/seerrplay_tvos
xcodegen generate
open SeerrPlayTV.xcodeproj
```

## Publishing

GitHub Actions validates mobile, desktop, and TV builds, publishes Android to
the Google Play internal track, uploads iOS, macOS, and tvOS to TestFlight, and deploys the public
privacy/support site. Configuration and secret names are documented in
[`docs/release-publishing.md`](docs/release-publishing.md).
