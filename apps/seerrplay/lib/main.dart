import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/app/seerrplay_app.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/features/notifications/application/request_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supportsMobileSystemUi) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(
    const RequestNotificationLifecycle(
      child: ProviderScope(child: SeerrPlayApp()),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      RequestNotificationService.initialize().catchError((Object _) {}),
    );
  });
}
