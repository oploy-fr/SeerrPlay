import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/downloads/application/download_progress_service.dart';
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
  final Map<String, int> _lastNativeProgress = {};
  StreamSubscription<NativeDownloadEvent>? _nativeEvents;

  String get _profileId =>
      ref.read(appSessionControllerProvider).requireValue.profile!.id;

  String get _storageKey => 'offline_downloads_v1_$_profileId';

  @override
  Future<List<OfflineDownload>> build() async {
    await _nativeEvents?.cancel();
    if (DownloadProgressService.usesNativeBackgroundDownloads) {
      _nativeEvents = DownloadProgressService.events.listen(_onNativeEvent);
      ref.onDispose(() => _nativeEvents?.cancel());
    }
    final profileId = ref
        .watch(appSessionControllerProvider)
        .requireValue
        .profile!
        .id;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('offline_downloads_v1_$profileId');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final restored = decoded
        .whereType<Map>()
        .map(
          (value) => OfflineDownload.fromJson(
            value.map((key, item) => MapEntry('$key', item)),
          ),
        )
        .where((download) => download.id.isNotEmpty)
        .toList(growable: false);
    final available = <OfflineDownload>[];
    for (final download in restored) {
      final file = File(download.filePath);
      if (download.status == OfflineDownloadStatus.completed) {
        if (await file.exists()) available.add(download);
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
            ),
          );
          continue;
        }
        if (nativeStatus?.status == 'downloading') {
          available.add(
            download.copyWith(
              progress: nativeStatus!.progress,
              downloadedBytes: nativeStatus.downloadedBytes,
              totalBytes: nativeStatus.totalBytes,
            ),
          );
          continue;
        }
      }
      if (await file.exists()) await file.delete();
      available.add(
        download.copyWith(
          status: OfflineDownloadStatus.failed,
          error: 'Download interrupted.',
        ),
      );
    }
    await _persist(available);
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
    final directory = await _downloadDirectory();
    final id = '${_profileId}_${playable.id}';
    final filePath = '${directory.path}/$id.$container';
    final existingFile = File(filePath);
    if (await existingFile.exists()) await existingFile.delete();
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
      totalBytes: option.estimatedBytes,
    );
    state = AsyncData([
      entry,
      ...current.where(
        (download) => download.sourceItemId != preparation.sourceItemId,
      ),
    ]);
    await _persist(state.requireValue);

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
        );
      } catch (_) {
        _replace(
          id,
          (download) => download.copyWith(
            status: OfflineDownloadStatus.failed,
            error: 'Unable to download this media.',
          ),
        );
        await _persist(state.requireValue);
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
          if (!state.hasValue) return;
          final progress = total <= 0 ? 0.0 : received / total;
          _replace(
            id,
            (download) => download.copyWith(
              progress: progress.clamp(0, 1),
              downloadedBytes: received,
              totalBytes: total > 0 ? total : download.totalBytes,
            ),
          );
          unawaited(
            DownloadProgressService.showAndroidProgress(
              id: id,
              title: entry.title,
              progress: progress,
            ),
          );
        },
      );
      final size = await File(filePath).length();
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
    } on DioException catch (error) {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
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
    } finally {
      _cancelTokens.remove(id);
      await _persist(state.requireValue);
    }
  }

  Future<void> delete(String id) async {
    _cancelTokens.remove(id)?.cancel();
    if (DownloadProgressService.usesNativeBackgroundDownloads) {
      await DownloadProgressService.cancelNativeDownload(id);
    } else {
      await DownloadProgressService.cancelAndroidProgress(id);
    }
    final download = state.requireValue
        .where((item) => item.id == id)
        .firstOrNull;
    if (download == null) return;
    final file = File(download.filePath);
    if (await file.exists()) await file.delete();
    state = AsyncData(
      state.requireValue.where((item) => item.id != id).toList(growable: false),
    );
    await _persist(state.requireValue);
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

  void _onNativeEvent(NativeDownloadEvent event) {
    if (!state.hasValue) return;
    final percentage = (event.progress.clamp(0, 1) * 100).round();
    if (event.status == 'downloading' &&
        _lastNativeProgress[event.id] == percentage) {
      return;
    }
    _lastNativeProgress[event.id] = percentage;
    _replace(
      event.id,
      (download) => download.copyWith(
        status: switch (event.status) {
          'completed' => OfflineDownloadStatus.completed,
          'failed' => OfflineDownloadStatus.failed,
          _ => OfflineDownloadStatus.downloading,
        },
        progress: event.progress,
        downloadedBytes: event.downloadedBytes,
        totalBytes: event.totalBytes,
        error: event.status == 'failed'
            ? 'Unable to download this media.'
            : null,
      ),
    );
    if (event.status != 'downloading') {
      _lastNativeProgress.remove(event.id);
    }
    unawaited(_persist(state.requireValue));
  }

  Future<Directory> _downloadDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/SeerrPlay/downloads/$_profileId');
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _persist(List<OfflineDownload> downloads) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(downloads.map((download) => download.toJson()).toList()),
    );
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

String _resolutionLabel(int? width, int? height) {
  if (height == null || height <= 0) return '';
  if (height >= 2160 || (width ?? 0) >= 3840) return '4K';
  return '${height}p';
}
