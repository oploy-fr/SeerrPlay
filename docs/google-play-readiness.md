# Google Play publication readiness

This document tracks the work required to publish SeerrPlay on Google Play.
Keep it updated whenever the app's permissions, SDKs, data practices, supported
form factors, or review flow change.

## Implemented in the app

- [x] The Android app uses the SeerrPlay name, icon, and a 320 × 180 Android TV
  banner.
- [x] The app targets Android API 36 and includes 32-bit and 64-bit native
  architectures.
- [x] Native libraries are compatible with 16 KB Android page sizes.
- [x] The unused media-playback foreground-service permission has been removed.
  The base foreground-service permission remains because Google Cast and
  WorkManager merge it into the final manifest.
- [x] Notification permission is requested in context.
- [x] HTTP connections display an explicit credential-security warning and
  HTTPS remains the default.
- [x] Automatic Picture in Picture is disabled on Android TV while remaining
  available on supported phones and tablets.
- [x] Settings provide About, Privacy, Terms, licenses, local profile deletion,
  and a Google Cast data disclosure.
- [x] Production builds no longer silently use the Android debug signing key.
- [x] Release lint passes for the application module with
  `./gradlew :app:lintRelease`.

## Required before uploading

- [ ] Decide the permanent application ID before creating the Play Console app.
  The current value is `app.seerrplay.client`.
- [ ] Create and securely back up a dedicated upload keystore outside the
  repository.
- [ ] Copy `apps/seerrplay/android/key.properties.example` to
  `apps/seerrplay/android/key.properties`, fill in the real values, and build the
  signed AAB.
- [ ] Enroll in Play App Signing and keep both the upload key and recovery
  information in secure backups.
- [ ] Publish a public privacy policy on a stable HTTPS URL. It must match the
  in-app policy and the production SDK/data behavior.
- [ ] Publish a support page or support email address.
- [ ] Provide a stable, internet-accessible Seerr and Jellyfin review
  environment with non-expiring credentials and review-safe sample media.
- [ ] Complete Data safety, declaring Google Cast SDK technical data according
  to Google's current Cast SDK data-disclosure documentation.
- [ ] Review the Foreground service declaration shown by Play Console. If it is
  requested for the SDK-provided base permission, document the user-initiated
  Google Cast session and provide a short casting demonstration video.
- [ ] Complete App access, Ads, Content rating, Target audience, News apps, and
  all other applicable App content declarations.
- [ ] Select the phone/tablet form factors. Opt in to Android TV only after a
  full remote-control and TV playback test pass.
- [ ] Prepare a 512 × 512 store icon, 1024 × 500 feature graphic, phone
  screenshots, and at least one unaltered Android TV screenshot when TV is
  distributed.
- [ ] Ensure all listing text says that SeerrPlay is an independent,
  unofficial client for user-authorized personal servers.
- [ ] Use only original, licensed, or public-domain media and artwork in the
  store listing and review environment.
- [ ] Increase the `version` build number in `pubspec.yaml` for every uploaded
  release.
- [ ] If the Play developer account is a newly created personal account,
  complete Google's required closed test before requesting production access.

## Upload signing setup

Generate the upload key only once and store it securely:

```shell
keytool -genkeypair -v \
  -keystore /SECURE/PATH/seerrplay-upload.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

Then create `apps/seerrplay/android/key.properties` from the provided example.
Never commit the keystore, passwords, or `key.properties`.

Build and verify the publication artifact:

```shell
cd apps/seerrplay
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
cd android
./gradlew :app:lintRelease
```

The publication artifact is:

`apps/seerrplay/build/app/outputs/bundle/release/app-release.aab`

## Suggested Play review instructions

Replace every bracketed value before submission.

> SeerrPlay is an independent, unofficial client for media servers selected by
> the user. It communicates directly with the supplied Seerr and Jellyfin
> servers. It does not host, sell, index, or provide media and contains no
> torrent client.
>
> Seerr URL: [PUBLIC REVIEW URL]
> Jellyfin URL: [PUBLIC REVIEW URL]
> Username: [REVIEW USERNAME]
> Password: [REVIEW PASSWORD]
>
> Sign in with the supplied profile to browse, search, request, stream, cast,
> and download the authorized sample media. The credentials do not expire and
> no one-time code, location restriction, or administrator action is required.
>
> The app does not create remote accounts. Deleting a local profile removes its
> connection details and credentials from this device. Remote accounts remain
> managed by the configured server administrator.

## Data safety working position

This section is preparation guidance, not a substitute for reviewing every Play
Console question against the final production build.

- Account creation: no SeerrPlay cloud account is created.
- Local profiles: connection details and credentials are supplied by the user.
- Credentials: stored with operating-system secure storage.
- Media and playback data: exchanged directly with configured Seerr and
  Jellyfin servers.
- Downloads: stored locally and removable from the Downloads page.
- Notifications: generated locally from user-enabled periodic checks.
- Advertising and developer analytics: none currently included.
- Google Cast: the Cast SDK may collect technical app activity, device
  discovery, and cast-session metadata as documented by Google.

## Review risks to monitor

- The app cannot be reviewed without working public Seerr and Jellyfin
  credentials.
- Generic streaming-service wording, third-party logos, or copyrighted store
  screenshots may cause impersonation or intellectual-property review issues.
- Allowing HTTP is necessary for some local self-hosted servers but exposes
  credentials on an untrusted network. Keep HTTPS as the default and retain the
  explicit warning.
- Any future analytics, crash-reporting, advertising, authentication, or push
  SDK requires updates to Data safety, the privacy policy, and this checklist.
- Android TV distribution requires continued D-pad, focus, Back behavior,
  landscape, media-key, and playback testing on a real TV device.
