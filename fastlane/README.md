fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### sync_apple_signing

```sh
[bundle exec] fastlane sync_apple_signing
```

Create or refresh the encrypted Apple distribution assets in match

### apple_store_metadata

```sh
[bundle exec] fastlane apple_store_metadata
```

Upload iOS and macOS App Store metadata without touching tvOS

### apple_macos_screenshots

```sh
[bundle exec] fastlane apple_macos_screenshots
```

Upload the prepared macOS screenshots without touching tvOS

### apple_beta

```sh
[bundle exec] fastlane apple_beta
```

Build iOS, macOS and tvOS, then upload every Apple application to TestFlight

----


## Android

### android store_metadata

```sh
[bundle exec] fastlane android store_metadata
```

Upload the Google Play listing without uploading a build

### android internal

```sh
[bundle exec] fastlane android internal
```

Build the signed Android App Bundle and upload it to internal testing

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
