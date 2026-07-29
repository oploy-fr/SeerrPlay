# Store publishing from GitHub

SeerrPlay uses GitHub Actions to validate every change and publish signed store
builds without storing signing material in the repository.

## Automated flow

- `.github/workflows/ci.yml` runs formatting, analysis, tests, an Android App
  Bundle build, an unsigned iOS Release build, and an unsigned tvOS Release
  build on every pull request and push to `main`.
- `.github/workflows/publish.yml` runs for tags matching `v*` or manually from
  the Actions tab. It uploads Android to the Google Play internal-testing track
  and uploads iOS and tvOS to App Store Connect/TestFlight.
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
for `app.seerrplay.client`.

## Apple secrets

Create the App Store Connect records and identifiers before the first workflow:

- iOS: `app.seerrplay.client`
- Live Activity extension:
  `app.seerrplay.client.SeerrPlayDownloadActivity`
- tvOS: `app.seerrplay.tv`

Export an Apple Distribution certificate with its private key as a password
protected `.p12`. Create an App Store Connect API key that can upload builds and
manage signing resources.

Add these GitHub environment secrets:

- `APPLE_DISTRIBUTION_CERTIFICATE_BASE64`: base64 representation of the `.p12`.
- `APPLE_CERTIFICATE_PASSWORD`: `.p12` export password.
- `APPLE_API_PRIVATE_KEY_BASE64`: base64 representation of the `AuthKey_*.p8`.
- `APPLE_API_KEY_ID`: App Store Connect API key identifier.
- `APPLE_API_ISSUER_ID`: App Store Connect issuer identifier.
- `CI_KEYCHAIN_PASSWORD`: a strong random password used only for the temporary
  CI keychain.

The workflow creates and removes a temporary macOS keychain. Xcode obtains
provisioning profiles through the App Store Connect API using automatic signing.

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

5. Monitor **Actions → Publish store builds**.
6. Test Android through the internal track and Apple through TestFlight.
7. Promote the validated build and submit the completed Store listing for
   review.

Every new binary needs a higher Android build number and Apple build number,
even when the marketing version is unchanged.
