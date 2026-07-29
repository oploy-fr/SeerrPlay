# SeerrPlay for Apple TV

Native tvOS client for Seerr with Plex, Jellyfin and Emby playback. The app
communicates directly with the servers configured by the user.

## Included features

- Multiple local profiles with automatic restoration of the last active profile.
- Automatic media-server detection through Seerr.
- Seerr local, Jellyfin/Emby or Plex PIN authentication, with secrets in Keychain.
- Home screen with continue watching, next episodes, available requests, trends,
  popular movies and popular series.
- Seerr discovery, category filtering, API search and media details.
- Request creation, personal request history, status filtering and deletion of a
  pending personal request.
- Media-server library browsing and search, including movies, series, documentaries,
  anime and standalone videos.
- Actor pages with biography and media appearances.
- Native `AVPlayerViewController` playback with the Siri Remote, timeline,
  ten-second seek, audio tracks, subtitles, quality negotiation and AirPlay.
- Direct Play when tvOS supports the source, otherwise server-side HLS transcoding.
- Playback start, progress, pause and stop reporting to the active media server.
- English, French, Spanish, Italian and German system localization.
- Privacy manifest, local-network usage explanation, layered Apple TV icon and
  Top Shelf artwork.

Offline downloads and phone-style Picture in Picture are intentionally excluded:
tvOS is a streaming platform and does not expose those mobile workflows.

## Generate and build

```sh
cd /Users/charles/Code/SeerrPlay/apps/seerrplay_tvos
xcodegen generate
open SeerrPlayTV.xcodeproj
```

Select the `SeerrPlayTV` scheme, then choose an Apple TV simulator or a paired
Apple TV. Signing uses the Apple development team selected in Xcode.

Command-line validation:

```sh
xcodebuild \
  -project SeerrPlayTV.xcodeproj \
  -scheme SeerrPlayTV \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project SeerrPlayTV.xcodeproj \
  -scheme SeerrPlayTV \
  -destination 'generic/platform=tvOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## App Store preparation

Before archiving, set the production bundle identifier and signing team, review
the privacy and terms text shown in Settings, provide support/privacy URLs in App
Store Connect, and test Direct Play plus transcoding against the production
Plex, Jellyfin and Emby servers on physical Apple TV hardware.
