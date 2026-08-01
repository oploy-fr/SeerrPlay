import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NativeDownloadEvent {
  const NativeDownloadEvent({
    required this.id,
    required this.status,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    this.bytesPerSecond = 0,
    this.estimatedRemainingSeconds,
    this.error,
  });

  factory NativeDownloadEvent.fromMap(Map<Object?, Object?> map) {
    return NativeDownloadEvent(
      id: map['id'] as String? ?? '',
      status: map['status'] as String? ?? 'downloading',
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      bytesPerSecond: (map['bytesPerSecond'] as num?)?.toDouble() ?? 0,
      estimatedRemainingSeconds: (map['estimatedRemainingSeconds'] as num?)
          ?.toInt(),
      error: map['error'] as String?,
    );
  }

  final String id;
  final String status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final int? estimatedRemainingSeconds;
  final String? error;
}

class DownloadProgressService {
  DownloadProgressService._();

  static const _methodChannel = MethodChannel('seerrplay/downloads');
  static const _eventChannel = EventChannel('seerrplay/downloads/events');
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;
  static final Map<String, int> _lastProgress = {};

  static bool get usesNativeBackgroundDownloads =>
      Platform.isIOS && !Platform.isMacOS;

  static Stream<NativeDownloadEvent> get events => _eventChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map(
        (event) => NativeDownloadEvent.fromMap(
          Map<Object?, Object?>.from(event as Map),
        ),
      );

  static Future<void> startNativeDownload({
    required String id,
    required Uri url,
    required Map<String, String> headers,
    required String destinationPath,
    required String title,
    required int estimatedBytes,
    required bool preferEstimatedTotal,
  }) {
    return _methodChannel.invokeMethod<void>('start', {
      'id': id,
      'url': url.toString(),
      'headers': headers,
      'destinationPath': destinationPath,
      'title': title,
      'estimatedBytes': estimatedBytes,
      'preferEstimatedTotal': preferEstimatedTotal,
    });
  }

  static Future<NativeDownloadEvent?> nativeStatus(String id) async {
    final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'status',
      {'id': id},
    );
    return result == null ? null : NativeDownloadEvent.fromMap(result);
  }

  static Future<void> cancelNativeDownload(String id) {
    return _methodChannel.invokeMethod<void>('cancel', {'id': id});
  }

  static Future<void> showAndroidProgress({
    required String id,
    required String title,
    required double progress,
    int? estimatedRemainingSeconds,
    bool completed = false,
    bool failed = false,
  }) async {
    if (!Platform.isAndroid) return;
    await _initializeNotifications();
    final percentage = (progress.clamp(0, 1) * 100).round();
    if (!completed &&
        !failed &&
        _lastProgress[id] != null &&
        _lastProgress[id] == percentage) {
      return;
    }
    _lastProgress[id] = percentage;
    final notificationId = id.hashCode & 0x7fffffff;
    final body = failed
        ? 'Download failed'
        : completed
        ? 'Available offline'
        : estimatedRemainingSeconds == null
        ? 'Downloading · $percentage%'
        : 'Downloading · $percentage% · ${_formatRemainingTime(estimatedRemainingSeconds)} left';
    await _notifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'download_progress',
          'Downloads',
          channelDescription: 'Offline media download progress.',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          ongoing: !completed && !failed,
          autoCancel: completed || failed,
          showProgress: !completed && !failed,
          maxProgress: 100,
          progress: percentage,
          category: AndroidNotificationCategory.progress,
        ),
      ),
    );
    if (completed || failed) _lastProgress.remove(id);
  }

  static Future<void> cancelAndroidProgress(String id) async {
    if (!Platform.isAndroid) return;
    await _initializeNotifications();
    await _notifications.cancel(id: id.hashCode & 0x7fffffff);
    _lastProgress.remove(id);
  }

  static Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _notificationsInitialized = true;
  }
}

String _formatRemainingTime(int seconds) {
  if (seconds < 60) return '< 1 min';
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '$hours h' : '$hours h $remainingMinutes min';
}
