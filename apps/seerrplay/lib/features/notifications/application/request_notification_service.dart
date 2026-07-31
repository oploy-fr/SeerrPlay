import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/features/profiles/data/credential_store.dart';
import 'package:seerrplay/features/profiles/data/profile_repository.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:seerrplay/features/seerr/data/seerr_client.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';
import 'package:workmanager/workmanager.dart';

const requestStatusTaskIdentifier = 'app.seerrplay.client.request_status_poll';
const _requestStatusTaskName = 'request_status_poll';

@pragma('vm:entry-point')
void requestNotificationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != requestStatusTaskIdentifier &&
        task != _requestStatusTaskName &&
        task != Workmanager.iOSBackgroundTask) {
      return true;
    }
    try {
      DartPluginRegistrant.ensureInitialized();
      await RequestNotificationService.initializeNotifications();
      await RequestNotificationService.checkForChanges();
    } catch (_) {
      return true;
    }
    return true;
  });
}

final requestNotificationsControllerProvider =
    AsyncNotifierProvider<RequestNotificationsController, bool>(
      RequestNotificationsController.new,
    );

class RequestNotificationsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => RequestNotificationService.isEnabled();

  Future<bool> setEnabled(bool enabled) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => RequestNotificationService.setEnabled(enabled),
    );
    state = result;
    return result.value ?? false;
  }
}

class RequestNotificationService {
  RequestNotificationService._();

  static const _enabledKey = 'request_notifications_enabled_v1';
  static const _snapshotKeyPrefix = 'request_notification_snapshot_v1.';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;

  static Future<void> initialize() async {
    if (!supportsBackgroundRequestPolling) return;
    await Workmanager().initialize(requestNotificationCallbackDispatcher);
    await initializeNotifications();
    await scheduleIfEnabled();
  }

  static Future<void> initializeNotifications() async {
    if (_notificationsInitialized) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _notificationsInitialized = true;
  }

  static Future<bool> isEnabled() async {
    if (!supportsBackgroundRequestPolling) return false;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  static Future<bool> setEnabled(bool enabled) async {
    if (!supportsBackgroundRequestPolling) return false;
    await initializeNotifications();
    if (enabled && !await _requestPermission()) return false;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);
    if (enabled) {
      await _clearActiveProfileSnapshot();
      await _registerPeriodicTask();
      try {
        await checkForChanges();
      } catch (_) {}
    } else {
      await Workmanager().cancelByUniqueName(requestStatusTaskIdentifier);
    }
    return enabled;
  }

  static Future<void> scheduleIfEnabled() async {
    if (!supportsBackgroundRequestPolling) return;
    if (await isEnabled()) await _registerPeriodicTask();
  }

  static Future<void> checkWhenAppResumes() async {
    if (!supportsBackgroundRequestPolling) return;
    if (!await isEnabled()) return;
    try {
      await checkForChanges();
    } catch (_) {}
  }

  static Future<void> checkForChanges() async {
    if (!await isEnabled()) return;
    final preferences = await SharedPreferences.getInstance();
    final profile = await _readActiveProfile();
    if (profile == null) return;
    final credentials = await CredentialStore().readCredentials(profile.id);
    if (credentials == null) return;

    final client = SeerrClient(
      baseUrl: profile.seerrBaseUrl.toString(),
      sessionCookie: credentials.seerrSessionCookie,
    );
    final page = await client
        .userRequests(credentials.seerrUserId, take: 100)
        .timeout(const Duration(seconds: 20));
    final snapshotKey = '$_snapshotKeyPrefix${profile.id}';
    final previous = _decodeSnapshots(preferences.getString(snapshotKey));
    final current = <int, _RequestSnapshot>{
      for (final request in page.results)
        request.id: _RequestSnapshot.fromRequest(request),
    };

    if (previous.isNotEmpty) {
      for (final request in page.results) {
        final oldSnapshot = previous[request.id];
        if (oldSnapshot == null) continue;
        final event = _eventFor(oldSnapshot, current[request.id]!);
        if (event == null) continue;
        await _showRequestNotification(
          client: client,
          profile: profile,
          request: request,
          event: event,
          preferences: preferences,
        );
      }
    }

    await preferences.setString(snapshotKey, _encodeSnapshots(current));
  }

  static Future<void> _registerPeriodicTask() {
    return Workmanager().registerPeriodicTask(
      requestStatusTaskIdentifier,
      _requestStatusTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<bool> _requestPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;
    final iosGranted =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    return androidGranted && iosGranted;
  }

  static Future<ConnectionProfile?> _readActiveProfile() async {
    final repository = LocalProfileRepository();
    final profiles = await repository.readProfiles();
    if (profiles.isEmpty) return null;
    final activeId = await repository.readActiveProfileId();
    for (final profile in profiles) {
      if (profile.id == activeId) return profile;
    }
    return profiles.first;
  }

  static Future<void> _clearActiveProfileSnapshot() async {
    final profile = await _readActiveProfile();
    if (profile == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_snapshotKeyPrefix${profile.id}');
  }

  static Future<void> _showRequestNotification({
    required SeerrClient client,
    required ConnectionProfile profile,
    required SeerrMediaRequest request,
    required _RequestNotificationEvent event,
    required SharedPreferences preferences,
  }) async {
    final languageCode =
        preferences.getString(LocaleController.preferenceKey) ?? 'en';
    final localizations = AppLocalizations(Locale(languageCode));
    final title = await _requestTitle(client, request, languageCode);
    final body = switch (event) {
      _RequestNotificationEvent.approved => localizations.translate(
        'Your request was approved.',
      ),
      _RequestNotificationEvent.declined => localizations.translate(
        'Your request was declined.',
      ),
      _RequestNotificationEvent.failed => localizations.translate(
        'Your request could not be processed.',
      ),
      _RequestNotificationEvent.partiallyAvailable => localizations.translate(
        'Partially available on your media server.',
      ),
      _RequestNotificationEvent.available => localizations.translate(
        'Available now on your media server.',
      ),
    };
    final notificationId = (request.id * 10 + event.index) & 0x7fffffff;
    await _notifications.show(
      id: notificationId,
      title: title,
      body: profile.name.isEmpty ? body : '$body · ${profile.name}',
      payload: jsonEncode({
        'requestId': request.id,
        'tmdbId': request.media?.tmdbId,
        'mediaType': request.type.apiValue,
      }),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'request_updates',
          'Request updates',
          channelDescription:
              'Approval, processing, and availability updates from Seerr.',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
          groupKey: 'seerr_request_updates',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          threadIdentifier: 'seerr_request_updates',
        ),
      ),
    );
  }

  static Future<String> _requestTitle(
    SeerrClient client,
    SeerrMediaRequest request,
    String languageCode,
  ) async {
    final tmdbId = request.media?.tmdbId;
    if (tmdbId == null || tmdbId <= 0) return 'SeerrPlay';
    try {
      final details = request.type == SeerrMediaType.tv
          ? await client.tvDetails(tmdbId, language: languageCode)
          : await client.movieDetails(tmdbId, language: languageCode);
      return details.title.trim().isEmpty ? 'SeerrPlay' : details.title.trim();
    } catch (_) {
      return 'SeerrPlay';
    }
  }

  static _RequestNotificationEvent? _eventFor(
    _RequestSnapshot previous,
    _RequestSnapshot current,
  ) {
    if (current.availability == SeerrAvailability.available &&
        previous.availability != SeerrAvailability.available) {
      return _RequestNotificationEvent.available;
    }
    if (current.availability == SeerrAvailability.partiallyAvailable &&
        previous.availability != SeerrAvailability.partiallyAvailable) {
      return _RequestNotificationEvent.partiallyAvailable;
    }
    if (current.status == previous.status) return null;
    return switch (current.status) {
      SeerrRequestStatus.approved => _RequestNotificationEvent.approved,
      SeerrRequestStatus.declined => _RequestNotificationEvent.declined,
      SeerrRequestStatus.failed => _RequestNotificationEvent.failed,
      _ => null,
    };
  }

  static Map<int, _RequestSnapshot> _decodeSnapshots(String? source) {
    if (source == null || source.isEmpty) return const {};
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      return json.map(
        (key, value) => MapEntry(
          int.parse(key),
          _RequestSnapshot.fromJson(
            Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
          ),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  static String _encodeSnapshots(Map<int, _RequestSnapshot> snapshots) {
    return jsonEncode(
      snapshots.map((key, value) => MapEntry(key.toString(), value.toJson())),
    );
  }
}

class RequestNotificationLifecycle extends StatefulWidget {
  const RequestNotificationLifecycle({required this.child, super.key});

  final Widget child;

  @override
  State<RequestNotificationLifecycle> createState() =>
      _RequestNotificationLifecycleState();
}

class _RequestNotificationLifecycleState
    extends State<RequestNotificationLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      RequestNotificationService.checkWhenAppResumes();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _RequestNotificationEvent {
  approved,
  declined,
  failed,
  partiallyAvailable,
  available,
}

class _RequestSnapshot {
  const _RequestSnapshot({required this.status, required this.availability});

  factory _RequestSnapshot.fromRequest(SeerrMediaRequest request) {
    return _RequestSnapshot(
      status: request.status,
      availability: request.media?.availability ?? SeerrAvailability.unknown,
    );
  }

  factory _RequestSnapshot.fromJson(Map<String, dynamic> json) {
    return _RequestSnapshot(
      status: SeerrRequestStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => SeerrRequestStatus.unknown,
      ),
      availability: SeerrAvailability.values.firstWhere(
        (value) => value.name == json['availability'],
        orElse: () => SeerrAvailability.unknown,
      ),
    );
  }

  final SeerrRequestStatus status;
  final SeerrAvailability availability;

  Map<String, String> toJson() => {
    'status': status.name,
    'availability': availability.name,
  };
}
