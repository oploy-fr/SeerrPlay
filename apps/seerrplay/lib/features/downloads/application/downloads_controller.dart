import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/downloads/application/download_progress_service.dart';
import 'package:seerrplay/features/downloads/application/download_speed_estimator.dart';
import 'package:seerrplay/features/downloads/domain/offline_download.dart';
import 'package:seerrplay/features/downloads/domain/offline_download_option.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

final downloadsControllerProvider =
    AsyncNotifierProvider<DownloadsController, List<OfflineDownload>>(
      DownloadsController.new,
    );

class DownloadsController extends AsyncNotifier<List<OfflineDownload>> {
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, DownloadSpeedEstimator> _speedEstimators = {};
  final Map<String, DateTime> _lastDesktopProgressEmissionAt = {};
  StreamSubscription<NativeDownloadEvent>? _nativeEvents;
  Timer? _nativeStatusTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _refreshingNativeStatuses = false;
  String? _activeProfileId;

  String get _profileId =>
      _activeProfileId ??
      ref.read(appSessionControllerProvider).requireValue.profile!.id;

  static String _storageKeyFor(String profileId) =>
      'offline_downloads_v1_$profileId';

  @override
  Future<List<OfflineDownload>> build() async {
    final profileId = ref
        .watch(appSessionControllerProvider)
        .requireValue
        .profile!
        .id;
    _activeProfileId = profileId;
    await _nativeEvents?.cancel();
    _nativeStatusTimer?.cancel();
    _lifecycleListener?.dispose();
    if (DownloadProgressService.usesNativeBackgroundDownloads) {
      _nativeEvents = DownloadProgressService.events.listen(_onNativeEvent);
      _nativeStatusTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_refreshNativeStatuses()),
      );
      _lifecycleListener = AppLifecycleListener(
        onResume: () => unawaited(_refreshNativeStatuses()),
      );
    }
    ref.onDispose(() {
      for (final token in _cancelTokens.values) {
        token.cancel('Downloads controller disposed');
      }
      _cancelTokens.clear();
      _speedEstimators.clear();
      _lastDesktopProgressEmissionAt.clear();
      _nativeEvents?.cancel();
      _nativeStatusTimer?.cancel();
      _lifecycleListener?.dispose();
    });
    final preferences = await SharedPreferences.getInstance();
    final storageKey = _storageKeyFor(profileId);
    final raw = preferences.getString(storageKey);
    if (raw == null) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      await preferences.remove(storageKey);
      return const [];
    }
    if (decoded is! List) return const [];
    final restored = <OfflineDownload>[];
    for (final value in decoded.whereType<Map>()) {
      try {
        final download = OfflineDownload.fromJson(
          value.map((key, item) => MapEntry('$key', item)),
        );
        if (download.id.isNotEmpty) restored.add(download);
      } on Object {
        // Ignore a damaged entry while preserving all other offline media.
      }
    }
    final available = <OfflineDownload>[];
    for (final download in restored) {
      final file = await _resolveDownloadFile(download, profileId);
      final restoredDownload = file.path == download.filePath
          ? download
          : download.copyWith(filePath: file.path);
      if (download.status == OfflineDownloadStatus.completed) {
        if (await file.exists()) available.add(restoredDownload);
        continue;
      }
      if (DownloadProgressService.usesNativeBackgroundDownloads) {
        final nativeStatus = await DownloadProgressService.nativeStatus(
          download.id,
        );
        if (nativeStatus?.status == 'completed' && await file.exists()) {
          available.add(
            download.copyWith(
              status: OfflineDownloadStatus.completed,
              progress: 1,
              downloadedBytes: nativeStatus!.downloadedBytes,
              totalBytes: nativeStatus.totalBytes,
              filePath: file.path,
            ),
          );
          continue;
        }
        if (nativeStatus?.status == 'downloading') {
          final totalBytes = nativeStatus!.totalBytes > 0
              ? nativeStatus.totalBytes
              : download.totalBytes;
          final progress = nativeStatus.progress > 0
              ? nativeStatus.progress
              : totalBytes > 0
              ? nativeStatus.downloadedBytes / totalBytes
              : 0.0;
          available.add(
            restoredDownload.copyWith(
              progress: progress.clamp(0, 1),
              downloadedBytes: nativeStatus.downloadedBytes,
              totalBytes: totalBytes,
            ),
          );
          continue;
        }
      }
      if (await file.exists()) await file.delete();
      available.add(
        restoredDownload.copyWith(
          status: OfflineDownloadStatus.failed,
          error: 'Download interrupted.',
        ),
      );
    }
    await _persistForProfile(profileId, available);
    return available;
  }

  Future<OfflineDownloadPreparation> prepareDownload(
    MediaViewModel media,
  ) async {
    final sourceItemId = media.mediaServerItemId;
    if (sourceItemId == null || sourceItemId.isEmpty) {
      throw const FormatException(
        'This media is not linked to the media server.',
      );
    }
    final client = ref.read(mediaServerClientProvider);
    final playable = await client.getPlayableItem(sourceItemId);
    final playback = await client.getPlaybackInfo(playable.id);
    final source = playback.mediaSources.firstOrNull;
    if (source == null) {
      throw const FormatException('No video source available.');
    }
    return OfflineDownloadPreparation(
      sourceItemId: sourceItemId,
      playableItem: playable,
      mediaSource: source,
      options: _buildDownloadOptions(
        playable,
        source,
        supportsTranscoding: client.supportsTranscodedDownloads,
        serverName: client.serverType.displayName,
      ),
    );
  }

  Future<void> download(
    MediaViewModel media,
    OfflineDownloadPreparation preparation,
    OfflineDownloadOption option,
  ) async {
    final profileId = _profileId;
    final current = state.requireValue;
    if (current.any(
      (download) =>
          download.sourceItemId == preparation.sourceItemId &&
          download.status != OfflineDownloadStatus.failed,
    )) {
      return;
    }

    final client = ref.read(mediaServerClientProvider);
    final playable = preparation.playableItem;
    final source = preparation.mediaSource;
    final container = option.container;
    final directory = await _downloadDirectory(profileId);
    final id = '${profileId}_${playable.id}';
    final filePath = '${directory.path}/$id.$container';
    final existingFile = File(filePath);
    if (await existingFile.exists()) await existingFile.delete();
    if (!_ownsProfile(profileId) || !state.hasValue) return;
    final latest = state.requireValue;
    if (latest.any(
      (download) =>
          download.sourceItemId == preparation.sourceItemId &&
          download.status != OfflineDownloadStatus.failed,
    )) {
      return;
    }
    final entry = OfflineDownload(
      id: id,
      sourceItemId: preparation.sourceItemId,
      downloadedItemId: playable.id,
      title: playable.seriesName?.isNotEmpty == true
          ? '${playable.seriesName} · ${playable.name}'
          : media.title,
      kind: playable.type == 'Episode' ? MediaKind.episode : media.kind,
      filePath: filePath,
      createdAt: DateTime.now(),
      posterUrl: media.posterUrl,
      tmdbId: media.tmdbId,
      ageRating: media.ageRating,
      totalBytes: option.estimatedBytes,
    );
    state = AsyncData([
      entry,
      ...latest.where(
        (download) => download.sourceItemId != preparation.sourceItemId,
      ),
    ]);
    await _persistForProfile(profileId, state.requireValue);

    final cancelToken = CancelToken();
    _cancelTokens[id] = cancelToken;
    // Plex exposes original files through its playback URL, while the
    // MediaBrowser servers provide a dedicated download endpoint. Compatible
    // copies always use the server's transcoding pipeline.
    final sourceUri = option.transcodes
        ? client.compatibleDownloadUri(
            itemId: playable.id,
            mediaSourceId: source.id,
            maxVideoBitrate: option.maxVideoBitrate!,
            maxWidth: option.maxWidth!,
            maxHeight: option.maxHeight!,
          )
        : client.serverType == MediaServerType.plex
        ? client.playbackUri(playable.id, source)
        : client.downloadUri(playable.id);
    if (DownloadProgressService.usesNativeBackgroundDownloads) {
      try {
        await DownloadProgressService.startNativeDownload(
          id: id,
          url: sourceUri,
          headers: client.downloadHeaders(),
          destinationPath: filePath,
          title: entry.title,
          estimatedBytes: entry.totalBytes,
          preferEstimatedTotal: option.transcodes,
        );
      } catch (_) {
        if (_ownsProfile(profileId) && state.hasValue) {
          _replace(
            id,
            (download) => download.copyWith(
              status: OfflineDownloadStatus.failed,
              error: 'Unable to download this media.',
            ),
          );
          await _persistForProfile(profileId, state.requireValue);
        }
      } finally {
        _cancelTokens.remove(id);
      }
      return;
    }

    await DownloadProgressService.showAndroidProgress(
      id: id,
      title: entry.title,
      progress: 0,
    );
    try {
      await client.downloadItem(
        playable.id,
        filePath,
        sourceUri: sourceUri,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (!_ownsProfile(profileId) || !state.hasValue) return;
          final now = DateTime.now();
          final lastEmission = _lastDesktopProgressEmissionAt[id];
          if (lastEmission != null &&
              now.difference(lastEmission) < const Duration(seconds: 1)) {
            return;
          }
          _lastDesktopProgressEmissionAt[id] = now;
          final knownTotal = _effectiveDownloadTotal(
            serverTotal: total,
            estimatedTotal: entry.totalBytes,
            downloadedBytes: received,
            preferEstimatedTotal: option.transcodes,
          );
          final progress = knownTotal <= 0
              ? 0.0
              : (received / knownTotal).clamp(0.0, 0.99);
          final estimate = _speedEstimators
              .putIfAbsent(id, DownloadSpeedEstimator.new)
              .update(downloadedBytes: received, totalBytes: knownTotal);
          _replace(
            id,
            (download) => download.copyWith(
              progress: progress.clamp(0, 1),
              downloadedBytes: received,
              totalBytes: knownTotal,
              bytesPerSecond: estimate?.bytesPerSecond,
              estimatedRemainingSeconds: estimate?.remainingSeconds,
            ),
          );
          unawaited(
            DownloadProgressService.showAndroidProgress(
              id: id,
              title: entry.title,
              progress: progress,
              estimatedRemainingSeconds: estimate?.remainingSeconds,
            ),
          );
        },
      );
      final size = await File(filePath).length();
      if (size <= 0) {
        throw DioException(
          requestOptions: RequestOptions(path: sourceUri.toString()),
          error: 'The downloaded file is empty.',
        );
      }
      if (!_ownsProfile(profileId) || !state.hasValue) {
        await _updatePersistedDownload(
          profileId,
          id,
          (download) => download.copyWith(
            status: OfflineDownloadStatus.completed,
            progress: 1,
            downloadedBytes: size,
            totalBytes: size,
          ),
        );
        return;
      }
      _replace(
        id,
        (download) => download.copyWith(
          status: OfflineDownloadStatus.completed,
          progress: 1,
          downloadedBytes: size,
          totalBytes: size,
        ),
      );
      await DownloadProgressService.showAndroidProgress(
        id: id,
        title: entry.title,
        progress: 1,
        completed: true,
      );
      _speedEstimators.remove(id);
      _lastDesktopProgressEmissionAt.remove(id);
    } on DioException catch (error) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      if (CancelToken.isCancel(error) ||
          !_ownsProfile(profileId) ||
          !state.hasValue ||
          !_contains(id)) {
        return;
      }
      _replace(
        id,
        (download) => download.copyWith(
          status: OfflineDownloadStatus.failed,
          error: error.response?.statusCode == 403
              ? 'The media server does not allow this account to download media.'
              : 'Unable to download this media.',
        ),
      );
      await DownloadProgressService.showAndroidProgress(
        id: id,
        title: entry.title,
        progress: 0,
        failed: true,
      );
    } catch (_) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
      if (!_ownsProfile(profileId) || !state.hasValue || !_contains(id)) {
        return;
      }
      _replace(
        id,
        (download) => download.copyWith(
          status: OfflineDownloadStatus.failed,
          error: 'Unable to download this media.',
        ),
      );
      await DownloadProgressService.showAndroidProgress(
        id: id,
        title: entry.title,
        progress: 0,
        failed: true,
      );
    } finally {
      _cancelTokens.remove(id);
      _speedEstimators.remove(id);
      _lastDesktopProgressEmissionAt.remove(id);
      if (_ownsProfile(profileId) && state.hasValue) {
        await _persistForProfile(profileId, state.requireValue);
      }
    }
  }

  Future<void> delete(String id) async {
    final profileId = _profileId;
    final download = state.value?.where((item) => item.id == id).firstOrNull;
    if (download == null) return;
    _cancelTokens.remove(id)?.cancel();
    _speedEstimators.remove(id);
    _lastDesktopProgressEmissionAt.remove(id);
    if (DownloadProgressService.usesNativeBackgroundDownloads) {
      await DownloadProgressService.cancelNativeDownload(id);
    } else {
      await DownloadProgressService.cancelAndroidProgress(id);
    }
    final file = File(download.filePath);
    if (await file.exists()) await file.delete();
    if (!_ownsProfile(profileId) || !state.hasValue) {
      await _removePersistedDownload(profileId, id);
      return;
    }
    state = AsyncData(
      state.requireValue.where((item) => item.id != id).toList(growable: false),
    );
    await _persist(state.requireValue);
  }

  Future<File?> localFileForItem(String itemId) async {
    if (itemId.isEmpty) return null;
    final profileId = _profileId;
    final completed = state.value
        ?.where(
          (download) =>
              download.status == OfflineDownloadStatus.completed &&
              (download.downloadedItemId == itemId ||
                  download.sourceItemId == itemId),
        )
        .firstOrNull;
    if (completed != null) {
      final file = await _resolveDownloadFile(completed, profileId);
      if (await file.exists()) return file;
    }
    final directory = await _downloadDirectory(profileId);
    final prefix = '${profileId}_$itemId.';
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.uri.pathSegments.last.startsWith(prefix)) {
        return entity;
      }
    }
    return null;
  }

  void _replace(
    String id,
    OfflineDownload Function(OfflineDownload download) update,
  ) {
    state = AsyncData([
      for (final download in state.requireValue)
        if (download.id == id) update(download) else download,
    ]);
  }

  bool _contains(String id) =>
      state.value?.any((download) => download.id == id) ?? false;

  bool _ownsProfile(String profileId) => _activeProfileId == profileId;

  void _onNativeEvent(NativeDownloadEvent event) {
    if (!state.hasValue) return;
    final current = state.requireValue
        .where((download) => download.id == event.id)
        .firstOrNull;
    if (current == null) return;
    final totalBytes = event.totalBytes > 0
        ? event.totalBytes
        : current.totalBytes;
    final progress = event.status == 'completed'
        ? 1.0
        : event.progress > 0
        ? event.progress
        : totalBytes > 0
        ? event.downloadedBytes / totalBytes
        : 0.0;
    _replace(
      event.id,
      (download) => download.copyWith(
        status: switch (event.status) {
          'completed' => OfflineDownloadStatus.completed,
          'failed' => OfflineDownloadStatus.failed,
          _ => OfflineDownloadStatus.downloading,
        },
        progress: progress.clamp(0, 1),
        downloadedBytes: event.downloadedBytes,
        totalBytes: totalBytes,
        bytesPerSecond: event.bytesPerSecond,
        estimatedRemainingSeconds: event.estimatedRemainingSeconds,
        error: event.status == 'failed'
            ? 'Unable to download this media.'
            : null,
      ),
    );
    unawaited(_persist(state.requireValue));
  }

  Future<void> _refreshNativeStatuses() async {
    if (!DownloadProgressService.usesNativeBackgroundDownloads ||
        _refreshingNativeStatuses ||
        !state.hasValue) {
      return;
    }
    _refreshingNativeStatuses = true;
    try {
      final activeDownloads = state.requireValue
          .where(
            (download) => download.status == OfflineDownloadStatus.downloading,
          )
          .toList(growable: false);
      for (final download in activeDownloads) {
        final nativeStatus = await DownloadProgressService.nativeStatus(
          download.id,
        );
        if (nativeStatus != null && state.hasValue) {
          _onNativeEvent(nativeStatus);
        }
      }
    } finally {
      _refreshingNativeStatuses = false;
    }
  }

  Future<Directory> _downloadDirectory([String? profileId]) async {
    final root = await getApplicationSupportDirectory();
    final ownerProfileId = profileId ?? _profileId;
    final directory = Directory(
      '${root.path}/SeerrPlay/downloads/$ownerProfileId',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _resolveDownloadFile(
    OfflineDownload download, [
    String? profileId,
  ]) async {
    final storedFile = File(download.filePath);
    if (await storedFile.exists()) return storedFile;
    final directory = await _downloadDirectory(profileId);
    final fileName = storedFile.uri.pathSegments.last;
    return File('${directory.path}/$fileName');
  }

  Future<void> _persist(List<OfflineDownload> downloads) async {
    await _persistForProfile(_profileId, downloads);
  }

  Future<void> _persistForProfile(
    String profileId,
    List<OfflineDownload> downloads,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKeyFor(profileId),
      jsonEncode(downloads.map((download) => download.toJson()).toList()),
    );
  }

  Future<void> _updatePersistedDownload(
    String profileId,
    String id,
    OfflineDownload Function(OfflineDownload download) update,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _storageKeyFor(profileId);
    final raw = preferences.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final downloads = <OfflineDownload>[];
      var found = false;
      for (final value in decoded.whereType<Map>()) {
        final download = OfflineDownload.fromJson(
          value.map((key, item) => MapEntry('$key', item)),
        );
        if (download.id == id) {
          downloads.add(update(download));
          found = true;
        } else {
          downloads.add(download);
        }
      }
      if (found) {
        await preferences.setString(
          key,
          jsonEncode(downloads.map((download) => download.toJson()).toList()),
        );
      }
    } on Object {
      // The active controller will repair invalid persisted data on next load.
    }
  }

  Future<void> _removePersistedDownload(String profileId, String id) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _storageKeyFor(profileId);
    final raw = preferences.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final downloads = decoded
          .whereType<Map>()
          .map(
            (value) => OfflineDownload.fromJson(
              value.map((key, item) => MapEntry('$key', item)),
            ),
          )
          .where((download) => download.id != id)
          .toList(growable: false);
      await preferences.setString(
        key,
        jsonEncode(downloads.map((download) => download.toJson()).toList()),
      );
    } on Object {
      // Invalid persisted data is cleaned when this profile is next opened.
    }
  }
}

String _safeExtension(String? container) {
  final value = container?.split(',').first.trim().toLowerCase() ?? '';
  return RegExp(r'^[a-z0-9]{2,5}$').hasMatch(value) ? value : 'media';
}

List<OfflineDownloadOption> _buildDownloadOptions(
  MediaServerItem item,
  MediaServerSource source, {
  required bool supportsTranscoding,
  required String serverName,
}) {
  final durationTicks = source.runTimeTicks ?? item.runTimeTicks ?? 0;
  final durationSeconds = durationTicks / 10000000;
  final videoStream = source.mediaStreams
      .where((stream) => stream.type == MediaStreamType.video)
      .firstOrNull;
  final audioStream = source.mediaStreams
      .where((stream) => stream.type == MediaStreamType.audio)
      .firstOrNull;
  final originalBitrate =
      source.bitrate ??
      ((videoStream?.bitRate ?? 0) + (audioStream?.bitRate ?? 0));
  final originalBytes =
      source.sizeBytes ??
      _estimatedBytes(
        durationSeconds: durationSeconds,
        bitrate: originalBitrate > 0 ? originalBitrate : 12000000,
      );
  final container = _safeExtension(source.container);
  final videoCodec = videoStream?.codec?.toLowerCase();
  final audioCodec = audioStream?.codec?.toLowerCase();
  final nativelyCompatible =
      const {'mp4', 'm4v', 'mov'}.contains(container) &&
      const {'h264', 'hevc', 'h265'}.contains(videoCodec) &&
      const {'aac', 'mp3', 'ac3', 'eac3'}.contains(audioCodec);
  final originalResolution = _resolutionLabel(
    videoStream?.width,
    videoStream?.height,
  );

  OfflineDownloadOption compatible({
    required String id,
    required String title,
    required int videoBitrate,
    required int width,
    required int height,
    bool recommended = false,
  }) {
    return OfflineDownloadOption(
      id: id,
      mode: OfflineDownloadMode.compatible,
      title: title,
      description: 'MP4 · H.264/AAC · Transcoded by $serverName',
      estimatedBytes: _estimatedBytes(
        durationSeconds: durationSeconds,
        bitrate: videoBitrate + 192000,
      ),
      container: 'mp4',
      maxVideoBitrate: videoBitrate,
      maxWidth: width,
      maxHeight: height,
      recommended: recommended,
    );
  }

  return [
    if (supportsTranscoding)
      compatible(
        id: 'compatible_1080p',
        title: 'Up to 1080p',
        videoBitrate: 8000000,
        width: 1920,
        height: 1080,
        recommended: true,
      ),
    if (supportsTranscoding)
      compatible(
        id: 'compatible_720p',
        title: 'Up to 720p',
        videoBitrate: 4000000,
        width: 1280,
        height: 720,
      ),
    if (supportsTranscoding)
      compatible(
        id: 'compatible_480p',
        title: 'Up to 480p',
        videoBitrate: 2000000,
        width: 854,
        height: 480,
      ),
    OfflineDownloadOption(
      id: 'original',
      mode: OfflineDownloadMode.original,
      title: 'Original quality',
      description: [
        originalResolution,
        container.toUpperCase(),
        'No transcoding',
      ].where((value) => value.isNotEmpty).join(' · '),
      estimatedBytes: originalBytes,
      container: container,
      nativeCompatibilityWarning: !nativelyCompatible,
    ),
  ];
}

int _estimatedBytes({required double durationSeconds, required int bitrate}) {
  if (durationSeconds <= 0 || bitrate <= 0) return 0;
  return (durationSeconds * bitrate / 8 * 1.05).round();
}

int _effectiveDownloadTotal({
  required int serverTotal,
  required int estimatedTotal,
  required int downloadedBytes,
  required bool preferEstimatedTotal,
}) {
  if (!preferEstimatedTotal || estimatedTotal <= 0) {
    return serverTotal > 0 ? serverTotal : estimatedTotal;
  }
  final plausibleServerTotal =
      serverTotal > 0 &&
      serverTotal >= estimatedTotal ~/ 4 &&
      serverTotal <= estimatedTotal + (estimatedTotal ~/ 2);
  if (plausibleServerTotal) return serverTotal;
  return estimatedTotal > downloadedBytes ? estimatedTotal : downloadedBytes;
}

String _resolutionLabel(int? width, int? height) {
  if (height == null || height <= 0) return '';
  if (height >= 2160 || (width ?? 0) >= 3840) return '4K';
  return '${height}p';
}
