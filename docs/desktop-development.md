# Desktop development

SeerrPlay now includes Flutter runners for macOS and Windows. The desktop apps
share the profiles, authentication, discovery, search, requests, downloads,
settings, and media detail features with the mobile application.

## Native playback

- macOS uses AVFoundation through Flutter's official video player backend.
- Windows uses Media Foundation through `video_player_win`.
- Jellyfin requests progressive H.264/AAC MP4 transcoding on Windows because
  the Media Foundation backend does not currently support HLS.
- macOS keeps the existing HLS profile.

The Windows Plex and Emby playback paths still need validation against real
servers. In particular, Plex transcodes commonly use HLS and may require a
progressive transcoding profile or a different Windows playback backend.

## Desktop interface

Wide windows use a navigation rail instead of the mobile bottom navigation.
The player supports these keyboard shortcuts:

- `Space`: play or pause
- `Left` / `Right`: seek backward or forward 10 seconds
- `M`: mute or restore sound
- `Escape`: close the player

Mobile-only Picture in Picture, Cast controls, screen orientation changes, and
periodic background request polling are disabled on desktop until native
desktop implementations are added.

## Build locally

macOS requires Xcode:

```sh
cd apps/seerrplay
flutter build macos --release
```

Windows must be built on Windows with Visual Studio and the **Desktop
development with C++** workload:

```powershell
cd apps\seerrplay
flutter build windows --release
```

Continuous integration builds both desktop targets. The Windows artifact is
compiled on a Windows runner because Flutter cannot cross-compile it from
macOS.

The macOS runner uses the existing multi-platform `app.seerrplay.client`
identifier and Keychain Sharing so profiles can securely persist credentials.
Local builds therefore require an Apple Development identity and a registered
Mac. Continuous integration compiles without code signing; distribution still
requires the App Store signing workflow.
