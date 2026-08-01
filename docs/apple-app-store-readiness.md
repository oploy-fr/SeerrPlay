# Apple App Store publication readiness

This document tracks the work required to publish SeerrPlay on Apple's App Store.
Keep it updated whenever the app's data practices, capabilities, or review flow
change.

## Implemented in the app

- [x] The iOS app is consistently named **SeerrPlay**.
- [x] Settings expose the app version and build number.
- [x] Settings provide About, Privacy, Terms, and open-source license pages.
- [x] Settings explain why local-network access is required.
- [x] Settings show the directly configured Seerr and media-server connections.
- [x] Users can remove a local profile and its locally stored credentials.
- [x] The app declares no tracking, no developer-collected data, and its
  app-specific UserDefaults required-reason API usage in
  `PrivacyInfo.xcprivacy`.
- [x] The local-network permission message describes its actual purpose.
- [x] Diagnostics copied from Settings exclude passwords, tokens, and API keys.

## Required before App Store submission

- [ ] Publish a public privacy policy on an HTTPS URL and add that URL to App
  Store Connect. The in-app privacy page does not replace this required URL.
- [ ] Publish a support page or support contact and configure the Support URL in
  App Store Connect.
- [ ] Provide Apple with a stable, internet-accessible Seerr and media-server
  review environment, including a non-administrator demo account, or implement
  a complete built-in demo mode.
- [ ] Keep the review servers online and populated with review-safe sample
  content for the entire review period.
- [ ] Complete the App Privacy questionnaire from the app's real production data
  flows, including every future analytics, crash-reporting, or support SDK.
- [ ] Complete the age-rating questionnaire and confirm the rights to display,
  download, and play all media visible to the review account.
- [ ] Review export-compliance answers for HTTPS and platform-provided
  encryption.
- [ ] Prepare final iPhone and iPad screenshots. Prepare Apple TV screenshots
  only when the tvOS target is production-ready.
- [ ] Test login, requests, playback, downloads, notifications, AirPlay,
  Picture in Picture, profile deletion, and unavailable-server errors using the
  release build.
- [ ] Upload a release build to TestFlight and complete an external beta pass
  before submission.
- [ ] Verify the final bundle identifier, signing team, version, build number,
  entitlements, capabilities, and App Store Connect record.
- [ ] Ensure metadata does not imply affiliation with Seerr, Jellyfin, Emby,
  Plex, Netflix, Canal+, or Apple.

## Account deletion position

SeerrPlay does not create Seerr, Plex, Jellyfin, or Emby accounts. It connects
to accounts created and controlled on user-selected third-party servers. The
app therefore offers deletion of its local profile, credentials, preferences,
and session data. Remote account deletion remains the responsibility of the
relevant server administrator. If SeerrPlay later adds account creation, it
must also add in-app account deletion.

## Suggested App Review notes

Replace every bracketed value before submission.

> SeerrPlay is an independent client for a user's authorized personal media
> services. It communicates directly with the Seerr and Plex, Jellyfin, or Emby
> servers chosen by the user. SeerrPlay does not host, sell, index, or provide
> media, and it contains no torrent client.
>
> Review account:
> Seerr URL: [PUBLIC REVIEW URL]
> Media-server URL: [PUBLIC REVIEW URL]
> Username: [REVIEW USERNAME]
> Password: [REVIEW PASSWORD]
>
> To review the main flow, sign in with the supplied profile, browse or search
> for a title, open its details, submit a request, and play an available sample
> title. Offline downloads, native playback, AirPlay, Picture in Picture,
> request tracking, and multi-profile switching are integrated into the same
> client.
>
> The app does not create remote accounts. “Delete local profile data” in
> Settings removes the profile and locally stored credentials from the device.
> Remote accounts are managed by the administrator of the configured server.
>
> Local Network permission is used only when a configured Seerr or media
> server is hosted on the reviewer's local network.

## Review risks to monitor

- A self-hosted app without a working public review environment can be rejected
  as incomplete.
- Generic store metadata or close imitation of another service can trigger
  design, copycat, or spam concerns. Emphasize SeerrPlay's unified request,
  playback, offline, profile, and native-platform experience.
- Any future SDK that collects diagnostics, analytics, identifiers, or user
  content requires updates to the privacy manifest, privacy policy, App Privacy
  answers, and this checklist.
- Background processing and notifications must provide visible user value and
  must not be described as guaranteed real-time server push while periodic
  polling is in use.
