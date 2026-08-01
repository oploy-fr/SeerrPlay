# Store publishing from GitHub

SeerrPlay uses GitHub Actions to validate every change and publish signed store
builds without storing signing material in the repository.

## Automated flow

- `.github/workflows/ci.yml` runs formatting, analysis, tests, an Android App
  Bundle build, an unsigned iOS Release build, and an unsigned tvOS Release
  build on every pull request and push to `main`.
- `.github/workflows/publish.yml` runs for tags matching `v*` or manually from
  the Actions tab. GitHub Actions invokes the same Fastlane lanes that can be
  run locally: Android is uploaded to the Google Play internal-testing track,
  while iOS, macOS, and tvOS are uploaded to App Store Connect/TestFlight. Manual runs
  can target Android, Apple, or all stores; version tags always publish all
  configured platforms.
- `.github/workflows/pages.yml` publishes `store-site` to GitHub Pages for the
  public privacy-policy and support URLs.

Store review and production promotion remain deliberate console actions. A
successful GitHub workflow does not bypass Apple review, Google review, content
declarations, screenshots, or staged-release decisions.

## Repository setup

1. Use the public `oploy-fr/SeerrPlay` GitHub repository.
2. Push `main`, then enable GitHub Actions.
3. In **Settings → Pages**, select **GitHub Actions** as the source.
4. Create a protected GitHub environment named `store-publishing`. Optional
   required reviewers prevent an accidental store upload.
5. Keep GitHub secret scanning and push protection enabled.

The expected public URLs are:

- `https://oploy-fr.github.io/SeerrPlay/privacy.html`
- `https://oploy-fr.github.io/SeerrPlay/support.html`

If the repository name or owner changes, update `AppLinks`, the tvOS Credits
view, the support site, and the Store listings.

## Android secrets

Create a long-lived upload key, keep an encrypted offline backup, and enroll the
application in Play App Signing. Never commit the keystore or
`android/key.properties`.

Add these GitHub environment secrets:

- `ANDROID_KEYSTORE_BASE64`: base64 representation of the upload `.jks`.
- `ANDROID_KEY_ALIAS`: alias inside the upload keystore.
- `ANDROID_KEY_PASSWORD`: password for the key.
- `ANDROID_STORE_PASSWORD`: password for the keystore.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: complete Google Play service-account JSON.

The service account must be invited in Play Console and have release permission
for `app.seerrplay.client`. Fastlane `supply` uses this account to upload the
signed Android App Bundle to the internal track. Google Play requires the app
record and its first release to be created manually before `supply` can manage
later releases.

## Apple signing with match

Create one multi-platform App Store Connect record before the first workflow.
iOS, macOS, and tvOS share its Apple ID, SKU, and explicit bundle identifier:

- iOS, macOS, and tvOS: `app.seerrplay.client`
- Live Activity extension:
  `app.seerrplay.client.SeerrPlayDownloadActivity`

Create a separate private GitHub repository for Fastlane match, for example
`oploy-fr/SeerrPlay-Certificates`, and initialize its `main` branch with a
README. This repository contains only encrypted Apple distribution certificates
and provisioning profiles. Do not store signing assets in the public
application repository.

Create a team App Store Connect API key with the Admin role. Download the
`AuthKey_*.p8` file immediately because Apple only allows it to be downloaded
once. Fastlane uses this key both for provisioning and TestFlight uploads.

Before running CI for the first time, initialize the encrypted signing
repository from a trusted Mac:

```sh
export MATCH_GIT_URL="https://github.com/oploy-fr/SeerrPlay-Certificates.git"
export APPLE_API_KEY_ID="<key-id>"
export APPLE_API_ISSUER_ID="<issuer-id>"
export APPLE_API_PRIVATE_KEY_BASE64="$(base64 < ~/Downloads/AuthKey_<key-id>.p8 | tr -d '\n')"
export MATCH_PASSWORD="$(security find-generic-password \
  -a 'oploy-fr/SeerrPlay-Certificates' \
  -s 'SeerrPlay Fastlane Match' \
  -w)"
bundle exec fastlane sync_apple_signing
```

The Git credentials active on the Mac must be allowed to write to the private
match repository. The setup stores the match password in the macOS Keychain;
keep an additional offline backup because the encrypted signing repository
cannot be decrypted without it.

Add these GitHub environment secrets:

- `APPLE_API_PRIVATE_KEY_BASE64`: base64 representation of the `AuthKey_*.p8`.
- `APPLE_API_KEY_ID`: App Store Connect API key identifier.
- `APPLE_API_ISSUER_ID`: App Store Connect issuer identifier.
- `MATCH_PASSWORD`: password used to encrypt the match repository.
- `MATCH_GIT_PRIVATE_KEY`: private half of a dedicated GitHub deploy key
  installed on the private match repository. Enable write access so the manual
  signing workflow can create or renew encrypted assets.

Add this GitHub environment variable:

- `MATCH_GIT_URL`: SSH clone URL of the private match repository.

Fastlane `setup_ci` creates a temporary macOS keychain. Store publishing only
reads existing signing assets from match. Run **Refresh Apple signing assets**
manually after adding a platform or when a certificate or profile must be
created or renewed.

## Local Fastlane commands

Install the locked Ruby dependencies:

```sh
bundle install
```

Available release lanes:

```sh
bundle exec fastlane android internal build_number:2
bundle exec fastlane apple_beta build_number:2
bundle exec fastlane sync_apple_signing
```

The release lanes require the same environment values as GitHub Actions. The
signing synchronization lane is intentionally write-enabled and should only be
run from a trusted Mac when certificates or profiles need to be created or
renewed.

## Publishing a version

1. Update `version` in `apps/seerrplay/pubspec.yaml`.
2. Keep `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the tvOS
   `project.yml` aligned, then run `xcodegen generate`.
3. Merge the tested version to `main`.
4. Create and push a matching tag, for example:

   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```

5. Monitor **Actions → Publish store builds**. The workflow runs
   `fastlane android internal` and `fastlane apple_beta`.
6. Test Android through the internal track and iOS, macOS, and tvOS through
   TestFlight.
7. Promote the validated build and submit the completed Store listing for
   review.

Every new binary needs a higher Android build number and Apple build number,
even when the marketing version is unchanged.
