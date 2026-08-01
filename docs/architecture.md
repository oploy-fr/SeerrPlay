# SeerrPlay architecture

## Product boundaries

- Seerr owns discovery, metadata, availability, and Sonarr/Radarr requests.
- Plex, Jellyfin, or Emby owns libraries, playback negotiation, playback state,
  and offline media delivery.
- A local profile links exactly one Seerr instance to the media server declared
  by that instance.
- Credentials are isolated per profile in Keychain or Android Keystore.
- SeerrPlay has no intermediary backend and never embeds a torrent client.

## Flutter feature structure

Each feature follows the smallest useful subset of these layers:

- `domain`: immutable models and rules that do not depend on Flutter widgets.
- `data`: HTTP clients, platform adapters, and persistence implementations.
- `application`: Riverpod providers and orchestration across data sources.
- `presentation`: screens and widgets.

Shared media-server models live under `features/media_server`. Provider-specific
folders contain only protocol details that cannot be shared. In particular,
Plex must not leak Plex-shaped DTOs into screens, and Jellyfin names must not be
used for models also returned by Emby or Plex.

The `app` folder contains application-wide composition such as the root
navigation. The `core` folder is limited to cross-feature concerns such as
localization, theme, and reusable branding widgets.

Large presentation screens keep navigation and state orchestration in their
main `*_screen.dart` file. Screen-specific surfaces, controls, sheets, and
sections live in adjacent `part` files. This keeps those implementation details
library-private without exposing reusable-looking public APIs that are only
valid inside one screen.

## Dependency direction

Presentation reads application providers and domain models. Application code
coordinates clients through `MediaServerClient`; it must not branch on concrete
client classes. Data clients may decode provider payloads into shared domain
models. Data and application layers must not import presentation code.
Presentation screens may compose public screens and widgets from other features.

`client_providers.dart` is the composition root for an authenticated Flutter
session. It is the only place that chooses a concrete Plex, Jellyfin, or Emby
client for normal app usage.

## Media-server detection

Seerr's public settings expose `mediaServerType`:

- `1`: Plex
- `2`: Jellyfin
- `3`: Emby

Jellyfin and Emby share the MediaBrowser authentication contract. Their public
address comes from Seerr settings when available, with an available-media URL
as a fallback.

Plex uses the official PIN/OAuth flow because Seerr must not expose a user's
Plex token. After linking, SeerrPlay matches Plex resources against the machine
identifier found in Seerr media links and selects the best reachable
connection.

## Playback

- Android and Android TV use Media3 ExoPlayer through Flutter's native video
  integration.
- iOS and tvOS use AVPlayer/AVPlayerViewController.
- The media server remains responsible for direct play, remuxing, or
  transcoding based on the requested tracks, quality, and client capabilities.
- Track or quality changes create a replacement playback session. The current
  native controller stays alive until the new platform view renders, preventing
  audio-only transitions and allowing rollback when negotiation fails.

## API tolerance and cache

Seerr's OpenAPI schema does not always expose every field returned by deployed
servers. Provider identifiers are therefore optional and matching may use TMDB,
TVDB, or IMDb identifiers.

Only stable discovery and metadata GET requests are cached. Request status,
playback progress, and other user-specific live state bypass the cache. Equal
in-flight GET requests share one Future, and cache generations prevent an old
response from repopulating data after logout or explicit refresh.

## Comment policy

Comments explain constraints, protocol mismatches, ordering requirements, and
fallback decisions. They should not restate names or obvious control flow.
