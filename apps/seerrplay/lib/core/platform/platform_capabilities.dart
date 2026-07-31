import 'package:flutter/foundation.dart';

bool get isDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

bool get supportsMobileSystemUi =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

bool get supportsSystemPictureInPicture => supportsMobileSystemUi;

bool get supportsBackgroundRequestPolling => supportsMobileSystemUi;
