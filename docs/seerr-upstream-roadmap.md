# Seerr Upstream Improvement Roadmap

Last reviewed: 2026-07-24
Maintainer: SeerrPlay project
Status: living document

## Purpose

This document tracks improvements that could be contributed upstream to Seerr
to make native clients simpler, faster, safer, and more consistent with the
Seerr web application.

The proposals must remain useful to every third-party client. They should not
introduce SeerrPlay-specific response fields, product names, or mobile-only
assumptions into otherwise generic endpoints.

Whenever SeerrPlay adds a workaround for a Seerr API limitation, update this file
with:

1. the observed limitation;
2. the local workaround and its source file;
3. the desired upstream contract;
4. an upstream issue or pull request link;
5. the status and the Seerr version containing the change.

## Status legend

| Status | Meaning |
| --- | --- |
| Idea | Needs validation against current Seerr behavior |
| Ready | Small, backward-compatible PR with clear acceptance criteria |
| RFC | Requires maintainer agreement before implementation |
| Upstream issue | An issue exists and should be linked |
| In progress | An upstream PR is open |
| Released | Available in a stable Seerr release |
| Rejected | Upstream declined the proposal |

## Current upstream capabilities

Do not duplicate these features:

- Seerr already supports Email, Web Push, Discord, Webhook, Gotify, ntfy,
  Pushbullet, Pushover, Slack, and Telegram notification agents.
- Web Push is designed for supported browsers and installed PWAs. It requires
  HTTPS and does not provide a native iOS or Android device-token contract.
- Webhooks already expose notification type, media, request, user, image, TMDB,
  TVDB, IMDb, and availability template variables.
- `GET /settings/discover` exposes configured discovery sliders.
- `GET /search` supports text search and pagination but does not expose
  documented media-type, genre, provider, or availability filters.
- Seerr exposes genre, provider, trending, recommendation, similar-title,
  request, person, movie, TV, season, ratings, and media-server synchronization
  endpoints.

References:

- [Seerr API documentation](https://docs.seerr.dev/api/seerr-api/)
- [Search endpoint](https://docs.seerr.dev/api/search-for-movies-tv-shows-or-people/)
- [Discovery sliders endpoint](https://docs.seerr.dev/api/get-all-discover-sliders/)
- [Notification agents](https://docs.seerr.dev/using-seerr/notifications/)
- [Web Push](https://docs.seerr.dev/using-seerr/notifications/webpush/)
- [Webhook variables](https://docs.seerr.dev/using-seerr/notifications/webhook/)

## Deliberate non-goals

These features should remain the media server or client responsibility unless
Seerr maintainers explicitly expand the project's scope:

- streaming, transcoding, remuxing, and media-byte proxying;
- native player controls, subtitles, audio-track selection, AirPlay, and PiP;
- offline media file storage and playback;
- continue-watching position and next-episode playback state;
- storing or returning a user's media-server access token to third-party
  clients;
- client-side profile switching and local credential storage.

Seerr should provide stable availability and media-server item links. The
native client should then authenticate directly with Jellyfin, Emby, or Plex
for playback-related operations.

## Recommended upstream sequence

| Order | Proposal | Status | Effort | Client impact |
| --- | --- | --- | --- | --- |
| 1 | OpenAPI and response-contract corrections | Ready | Small | Very high |
| 2 | Filtered search endpoint | Ready | Small–medium | Very high |
| 3 | User request filter parity | Ready | Small | High |
| 4 | Scoped and revocable client tokens | RFC | Medium | Very high |
| 5 | Stable media-server item links | RFC | Medium | Very high |
| 6 | Incremental user event feed | RFC | Medium | Very high |
| 7 | Webhook signing and delivery reliability | Ready | Medium | High |
| 8 | Hydrated home/discovery contract | RFC | Medium | High |
| 9 | Batch media-state endpoint | RFC | Medium | High |
| 10 | Native device push agent | RFC | Large | Very high |
| 11 | Normalized download progress | RFC | Medium | Medium–high |

## P0 — API contract and correctness

### 1. Correct and continuously test the OpenAPI specification

Status: Ready

Observed problem:

- Runtime payloads contain useful fields that are missing, incomplete, or
  weakly typed in the published OpenAPI contract.
- Availability, request, download, and media-server identifiers need defensive
  parsing in native clients.
- Pagination shapes differ between discovery pages and request pages.

Current SeerrPlay workaround:

- Unknown enum values are preserved and many response fields are optional in
  [`seerr_models.dart`](../apps/seerrplay/lib/features/seerr/domain/seerr_models.dart).
- The architectural reason is documented in
  [`architecture.md`](architecture.md).

Proposed PR:

- Generate contract fixtures from real controller responses.
- Add schema tests that fail when the OpenAPI response differs from the runtime
  serializer.
- Document every availability and request status, including failed,
  blocklisted, deleted, partially available, and completed states.
- Document `jellyfinMediaId`, 4K identifiers, seasons, and download status when
  returned.
- Standardize nullable versus omitted properties.
- Add a shared paginated response schema where possible.
- Add a documented error envelope with a stable machine-readable code.

Acceptance criteria:

- A generated client can decode search, discovery, details, ratings, requests,
  seasons, and user requests without handwritten unknown-field workarounds.
- CI verifies the OpenAPI document against representative API responses.

### 2. Add filters to `GET /search`

Status: Ready

Observed problem:

- A category page cannot search the full Seerr catalog while remaining inside
  its movie/TV genre.
- The client must request up to several general search pages and then discard
  results whose `mediaType` or `genreIds` do not match.
- Reverse proxies do not always treat `+` and `%20` identically in query values,
  so encoded-space behavior deserves a regression test.

Current SeerrPlay workaround:

- [`category_screen.dart`](../apps/seerrplay/lib/features/home/presentation/category_screen.dart)
  calls `/search`, loads up to three pages, and filters them locally.
- [`seerr_client.dart`](../apps/seerrplay/lib/features/seerr/data/seerr_client.dart)
  explicitly percent-encodes search text.

Proposed request:

```http
GET /api/v1/search
  ?query=justice
  &page=1
  &language=fr
  &mediaType=movie
  &genreIds=18,53
  &watchRegion=FR
  &watchProviders=8,337
  &availability=all
  &includePeople=false
```

Suggested parameters:

| Parameter | Values |
| --- | --- |
| `mediaType` | `movie`, `tv`, `person`, `all` |
| `genreIds` | Comma-separated TMDB genre IDs |
| `watchRegion` | ISO 3166-1 country code |
| `watchProviders` | Comma-separated provider IDs |
| `availability` | `all`, `available`, `requested`, `unavailable` |
| `includePeople` | Boolean, defaults to current behavior |
| `language` | Consistent localization parameter |

Implementation notes:

- Keep all new parameters optional for backward compatibility.
- Apply filters in the upstream TMDB request whenever TMDB supports them.
- If TMDB cannot combine text search and a filter, document server-side
  post-filtering and its pagination semantics.
- Add tests for spaces, accents, apostrophes, emoji, and non-Latin scripts.
- Do not silently return a shorter page without exposing the post-filtered
  `totalResults` behavior.

### 3. Give user request endpoints the same filters as the global request list

Status: Ready

Observed problem:

- `GET /request` supports useful status, sort, user, and media-type filters.
- `GET /user/:userId/requests` exposes only `take` and `skip`.
- Native clients download a larger list and reproduce Seerr status filters
  locally.

Proposed request:

```http
GET /api/v1/user/7/requests
  ?take=20
  &skip=0
  &filter=available
  &mediaType=movie
  &sort=modified
  &sortDirection=desc
  &updatedAfter=2026-07-24T00:00:00Z
```

Acceptance criteria:

- Permissions remain identical to the existing user endpoint.
- Filter names and semantics match `GET /request`.
- `updatedAfter` uses a database index and returns deterministic ordering.

### 4. Add API capability discovery

Status: Ready

Observed problem:

- Self-hosted instances update independently.
- A client cannot know whether optional search filters, event cursors, or new
  response fields are available without attempting a request.

Proposed response extension:

```json
{
  "version": "3.x",
  "apiVersion": "1.1",
  "capabilities": [
    "search.filters",
    "requests.updatedAfter",
    "mediaServer.itemLinks.v1",
    "events.cursor.v1"
  ]
}
```

Implementation notes:

- Extend the existing status endpoint instead of creating a second version
  endpoint.
- Capability identifiers must describe contracts, not UI features.

### 5. Add scoped and revocable client access tokens

Status: RFC

Observed problem:

- Cookie authentication works for native clients but has browser-oriented
  lifecycle semantics.
- The instance-wide API key can provide administrative access and must never be
  embedded in or copied into an untrusted client.
- Users need to revoke one lost device without invalidating every session.

Suggested endpoints:

```http
POST   /api/v1/auth/tokens
GET    /api/v1/auth/tokens
DELETE /api/v1/auth/tokens/:tokenId
```

Example creation request:

```json
{
  "name": "Living room Apple TV",
  "scopes": [
    "profile:read",
    "media:read",
    "request:read",
    "request:create"
  ],
  "expiresInDays": 365
}
```

Requirements:

- Show the secret only once and store only its hash server-side.
- Associate tokens with one user and the user's current permissions.
- Reject a scope the user is not allowed to grant.
- Support optional expiry, last-used timestamp, device name, and revocation.
- Rate-limit token creation and require recent authentication.
- Never include media-server, Sonarr, Radarr, notification-agent, or
  administrator secrets in token responses.
- Preserve cookies for the web UI and existing clients.

## P1 — Events and notifications

### 6. Add an incremental authenticated event feed

Status: RFC

Observed problem:

- SeerrPlay periodically downloads the user's request list to detect approval,
  decline, failure, partial availability, and full availability.
- Periodic mobile background work is delayed by iOS and Android and wastes
  server resources when nothing changed.
- Existing webhooks require a publicly reachable receiver and therefore cannot
  target a backendless mobile client directly.

Smallest useful design:

```http
GET /api/v1/user/me/events?after=01J...&limit=100
```

```json
{
  "events": [
    {
      "id": "01J...",
      "type": "MEDIA_AVAILABLE",
      "createdAt": "2026-07-24T10:15:00Z",
      "requestId": 123,
      "mediaType": "movie",
      "tmdbId": 550,
      "mediaStatus": "AVAILABLE",
      "title": "Example",
      "imageUrl": "/image/..."
    }
  ],
  "nextCursor": "01J..."
}
```

Requirements:

- Events are scoped to what the authenticated user is allowed to see.
- Cursors are opaque, stable, and resumable.
- Retention is documented.
- Duplicate delivery is allowed; event IDs make processing idempotent.
- The first PR can use short polling. SSE or WebSocket delivery can be a later
  enhancement using the same event schema.

Benefits:

- Reliable foreground refresh.
- Much cheaper periodic background checks.
- Shared foundation for native push, web push, webhooks, and future clients.

### 7. Add native APNs/FCM device notifications

Status: RFC

This is not a replacement for existing Web Push. Web Push subscriptions belong
to browsers/PWAs, while native apps register APNs or FCM device tokens.

Suggested endpoints:

```http
POST   /api/v1/user/me/devices
PATCH  /api/v1/user/me/devices/:deviceId
DELETE /api/v1/user/me/devices/:deviceId
GET    /api/v1/user/me/devices
```

Example registration:

```json
{
  "platform": "apns",
  "token": "opaque-device-token",
  "appId": "app.example.client",
  "environment": "production",
  "locale": "fr-FR",
  "events": [
    "REQUEST_APPROVED",
    "REQUEST_DECLINED",
    "REQUEST_FAILED",
    "MEDIA_PARTIALLY_AVAILABLE",
    "MEDIA_AVAILABLE"
  ]
}
```

Server requirements:

- Per-user opt-in preferences.
- Token rotation and invalid-token cleanup.
- Multiple devices per user.
- APNs and FCM credentials configured by the Seerr administrator.
- No third-party hosted relay required by default.
- Deep-link data based on stable media and request IDs.
- Payloads contain no sensitive synopsis or user data by default.
- Delivery retries use the shared event ID for deduplication.

Recommended delivery:

- Start with an upstream design discussion.
- Reuse the event schema from proposal 6.
- Implement APNs and FCM as notification agents rather than embedding provider
  logic inside request services.

### 8. Sign webhook deliveries and expose delivery diagnostics

Status: Ready

Existing webhooks support authorization and custom headers, which is useful,
but a generated signature is safer and easier to validate consistently.

Proposed headers:

```text
Seerr-Event-Id: 01J...
Seerr-Event-Type: MEDIA_AVAILABLE
Seerr-Delivery-Attempt: 1
Seerr-Timestamp: 1784897700
Seerr-Signature-256: sha256=<hex-hmac>
```

Proposed additions:

- Per-webhook signing secret.
- HMAC over timestamp plus raw body.
- Retry policy with exponential backoff.
- Delivery history containing status code, duration, attempt count, and a
  redacted error.
- Manual redelivery.
- Stable JSON schema mode in addition to the customizable template mode.

## P1 — Discovery parity

### 9. Add a hydrated home/discovery endpoint

Status: RFC

Observed problem:

- Native clients can read discovery settings and individual discovery
  endpoints, but reproducing the exact web dashboard order and content requires
  knowledge of Seerr's frontend composition rules.
- Popular and trending sections can differ from the web dashboard when the
  client guesses which endpoints, pages, region, language, or hidden-media
  settings to use.

Proposed request:

```http
GET /api/v1/discover/home?language=fr&region=FR&itemsPerSlider=20
```

Proposed response:

```json
{
  "sections": [
    {
      "id": "trending",
      "type": "builtin",
      "title": "Trending",
      "mediaType": "all",
      "items": [],
      "nextPage": 2
    },
    {
      "id": "genre-movie-28",
      "type": "genre",
      "title": "Action",
      "mediaType": "movie",
      "items": [],
      "nextPage": 2
    }
  ]
}
```

Requirements:

- Respect global and user-specific discover language and region.
- Respect slider order, disabled sliders, custom sliders, hidden available
  media, and blocklisted content.
- Reuse the same service functions as the web dashboard to prevent drift.
- Return stable slider IDs suitable for pagination and caching.

Alternative smaller PR:

- Add a generic resolver endpoint for one slider definition returned by
  `/settings/discover`.

### 10. Add country and provider ranking contracts

Status: Idea

Goal:

- Support "Top 10 in France" or provider-oriented sections without pretending
  that a normal popularity list is an official provider chart.

Constraints:

- TMDB provider availability is not the same as Netflix, Disney+, or Prime
  Video ranking data.
- Seerr should expose the source and meaning of every ranking.

Possible response metadata:

```json
{
  "title": "Trending in France",
  "region": "FR",
  "providerId": 8,
  "rankingSource": "tmdb_popularity",
  "isOfficialProviderChart": false,
  "items": []
}
```

Do not merge this proposal until the data source and naming are unambiguous.

## P1 — Media availability and playback links

### 11. Replace server-specific media ID fields with a stable link collection

Status: RFC

Observed problem:

- `jellyfinMediaId` and `jellyfinMediaId4k` are useful but couple clients to
  one server type and two hard-coded quality variants.
- Future Plex and Emby support needs a generic representation.
- Series, season, episode, library, and version mappings are not represented by
  one consistent contract.

Proposed response:

```json
{
  "mediaServerLinks": [
    {
      "serverType": "jellyfin",
      "serverId": 1,
      "libraryId": "library-id",
      "itemId": "item-id",
      "itemType": "movie",
      "qualityVariant": "standard",
      "isPrimary": true,
      "lastSeenAt": "2026-07-24T09:00:00Z"
    }
  ]
}
```

Requirements:

- Never expose media-server access tokens.
- Preserve the old Jellyfin fields during a deprecation period.
- Support multiple versions without assuming only standard and 4K.
- Document whether IDs point to a series, season, episode, or movie.
- Document that items without a TMDB/TVDB match are absent from Seerr
  discovery even though they remain playable on the media server.

### 11a. Optionally expose unmatched media-server library items

Status: Idea

Observed problem:

- Documentaries, anime, home videos, concerts, and custom metadata can exist in
  Jellyfin without a TMDB or TVDB match.
- Those items cannot be discovered through Seerr movie or TV endpoints.
- Native clients must currently query the media server directly and merge a
  second catalog.

Possible direction:

- Add an authenticated, opt-in library catalog endpoint containing safe display
  metadata and the generic `mediaServerLinks` proposed above.
- Mark entries with `metadataSource: "local"` or
  `metadataMatchStatus: "unmatched"`.
- Respect each user's media-server library permissions.
- Never proxy streams or expose API keys through Seerr.

### 12. Expose episode-level availability and media-server mappings

Status: RFC

Observed problem:

- A partially available series needs season and episode status to explain what
  can be watched.
- Season status alone cannot identify the next playable episode or gaps inside
  a partially downloaded season.

Proposed addition:

```json
{
  "seasonNumber": 1,
  "status": "PARTIALLY_AVAILABLE",
  "episodes": [
    {
      "episodeNumber": 1,
      "status": "AVAILABLE",
      "mediaServerLinks": []
    }
  ]
}
```

Implementation notes:

- Make episode expansion optional, for example `include=episodes`.
- Avoid making normal list endpoints return thousands of episode objects.

### 13. Add a batch media-state endpoint

Status: RFC

Observed problem:

- Search, discovery, provider, cast-credit, recommendation, and similar-title
  lists need availability and request badges.
- Fetching details for every poster creates an N+1 request pattern.

Proposed request:

```http
POST /api/v1/media/state/batch
```

```json
{
  "items": [
    {"mediaType": "movie", "tmdbId": 550},
    {"mediaType": "tv", "tmdbId": 66732}
  ],
  "include": ["requests", "seasons", "mediaServerLinks", "downloads"]
}
```

Requirements:

- Enforce a documented maximum batch size.
- Preserve input order or return an explicit compound key.
- Apply the authenticated user's permissions.
- Support ETags or short-lived caching.

## P2 — Request and download lifecycle

### 14. Normalize Sonarr/Radarr download progress

Status: RFC

Observed problem:

- A client needs a stable distinction between requested, approved, queued,
  searching, downloading, importing, partially available, available, and
  failed.
- String-based queue statuses and optional progress values are difficult to
  present consistently.

Proposed object:

```json
{
  "state": "downloading",
  "progress": 0.72,
  "downloadedBytes": 12884901888,
  "totalBytes": 17895697066,
  "etaSeconds": 900,
  "protocol": "usenet",
  "quality": "WEBDL-1080p",
  "updatedAt": "2026-07-24T10:20:00Z",
  "errorCode": null
}
```

Requirements:

- `progress` is always between 0 and 1.
- Byte counts and ETA are nullable when the upstream service cannot provide
  them.
- A stable enum is used instead of exposing raw Sonarr/Radarr queue strings.
- Movie, series, season, and episode scopes are explicit.

### 15. Add idempotency support to request creation and retry

Status: Ready

Observed problem:

- Mobile connections may time out after Seerr accepted a request.
- Retrying can produce confusing "already requested" responses.

Proposed header:

```text
Idempotency-Key: <client-generated UUID>
```

Requirements:

- Scope keys to the authenticated user and route.
- Return the original successful response for a duplicate key.
- Document retention time.

### 16. Return server-selected request defaults before submission

Status: Idea

Goal:

- Let clients display the same Sonarr/Radarr server, root folder, quality,
  language, and override-rule choices as the Seerr web request dialog without
  duplicating selection logic.

Possible endpoint:

```http
GET /api/v1/request/options?mediaType=tv&mediaId=66732
```

The response should distinguish:

- fixed values selected by administrator rules;
- defaults the user may change;
- choices hidden by permissions;
- reasons a request cannot be created.

Related upstream discussion:

- [Multiple request profiles issue #1737](https://github.com/seerr-team/seerr/issues/1737)

## P2 — Performance and client ergonomics

### 17. Add ETag and conditional-request support

Status: Idea

Candidate endpoints:

- public and main settings;
- user settings;
- genres and providers;
- discovery sliders;
- media details and ratings;
- user request pages;
- batch media states.

Acceptance criteria:

- Stable ETags vary by authenticated representation.
- `If-None-Match` returns `304` without rebuilding expensive remote data.
- Private responses keep appropriate cache-control directives.

### 18. Return canonical image URLs

Status: Idea

Observed problem:

- Clients reconstruct TMDB URLs and sizes themselves.
- Seerr image caching may be enabled, but clients cannot use one consistent
  canonical URL contract across all response types.

Proposed fields:

```json
{
  "images": {
    "poster": {
      "original": "https://seerr.example/image/...",
      "w342": "https://seerr.example/image/..."
    },
    "backdrop": {
      "w1280": "https://seerr.example/image/..."
    }
  }
}
```

Requirements:

- Preserve existing TMDB paths for compatibility.
- Use Seerr's externally configured application URL.
- Document cache lifetime and fallback behavior.

### 19. Add consistent localization and region parameters

Status: Ready

Proposed convention:

- `language`: BCP 47-compatible metadata locale.
- `region`: ISO 3166-1 discovery/release region.
- `watchRegion`: provider availability region only.
- Omitted values resolve from user settings, then global settings.

Apply the same convention to search, details, credits, ratings, releases,
recommendations, similar titles, genres, providers, and discovery endpoints.

### 20. Add rate-limit and timeout metadata

Status: Idea

Proposed response headers:

```text
RateLimit-Limit
RateLimit-Remaining
RateLimit-Reset
Retry-After
```

Also return stable error codes for:

- TMDB timeout;
- Sonarr/Radarr timeout;
- media-server timeout;
- permission failure;
- upstream rate limit;
- invalid filter combination.

## Pull request preparation checklist

Before opening any Seerr PR:

- [ ] Search existing issues and pull requests for duplicates.
- [ ] Open an issue or discussion first for every item marked RFC.
- [ ] Confirm behavior against the current `develop` branch.
- [ ] Keep the first PR small and backward compatible.
- [ ] Update `seerr-api.yml`.
- [ ] Add controller/service unit tests.
- [ ] Add API integration or contract fixtures.
- [ ] Update generated documentation.
- [ ] Add migration steps only when persistence changes.
- [ ] Avoid logging tokens, cookies, webhook secrets, or device tokens.
- [ ] Document permissions and user scoping.
- [ ] Add the issue and PR links to this document.
- [ ] After release, record the first stable Seerr version containing the
      feature.

## Suggested first contributions

### PR 1 — Search encoding tests and optional `mediaType`

Why first:

- Very small surface area.
- Immediately removes client-side filtering for movie versus TV searches.
- Establishes a pattern for additional filters.

### PR 2 — `genreIds` and `includePeople` search filters

Why second:

- Directly fixes category search.
- Backward compatible.
- Can reuse the validation introduced in PR 1.

### PR 3 — User request filter parity

Why third:

- Reuses existing global request filter semantics.
- Reduces payloads and duplicated client logic.

### RFC 1 — Incremental user event feed

Why before native push:

- It solves foreground synchronization and improves periodic checks.
- It provides the event model needed by APNs, FCM, Web Push, and webhooks.
- It avoids coupling the first implementation to one push provider.

### RFC 2 — Generic media-server links

Why early:

- It prevents new clients from depending more deeply on Jellyfin-specific
  fields.
- It prepares Seerr for consistent Jellyfin, Emby, and Plex client links.

## Maintenance log

| Date | Change | Related code or upstream link |
| --- | --- | --- |
| 2026-07-24 | Initial roadmap created from SeerrPlay integration work | Search, discovery, requests, notifications, media links, and download lifecycle |
| 2026-07-24 | Recorded category-search workaround | [`category_screen.dart`](../apps/seerrplay/lib/features/home/presentation/category_screen.dart) |
| 2026-07-24 | Recorded periodic notification polling limitation | [`request_notification_service.dart`](../apps/seerrplay/lib/features/notifications/application/request_notification_service.dart) |
| 2026-07-26 | Recorded unmatched Jellyfin-library limitation and direct catalog fallback | [`jellyfin_library_screen.dart`](../apps/seerrplay/lib/features/home/presentation/jellyfin_library_screen.dart) |
