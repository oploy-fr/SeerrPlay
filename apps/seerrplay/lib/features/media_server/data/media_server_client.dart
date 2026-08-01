import 'package:dio/dio.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

abstract interface class MediaServerClient {
  Uri get baseUrl;
  MediaServerType get serverType;
  bool get supportsTranscodedDownloads;

  Future<MediaServerItemsPage> getResumeItems({
    int startIndex = 0,
    int limit = 20,
    List<String> includeItemTypes = const ['Movie', 'Episode'],
  });

  Future<MediaServerItemsPage> getLibraryItems({
    int startIndex = 0,
    int limit = 200,
    String searchTerm = '',
    List<String> includeItemTypes = const ['Movie', 'Series', 'Video'],
  });

  Future<MediaServerItemsPage> getNextUp({int startIndex = 0, int limit = 20});

  Future<MediaServerItemsPage> getRecentlyPlayedEpisodes({
    int startIndex = 0,
    int limit = 100,
  });

  Future<List<MediaServerItem>> getSeriesEpisodes(
    String seriesId, {
    int? seasonNumber,
  });

  Future<MediaServerItem> getItemDetails(String itemId);
  Future<MediaServerItem> getPlayableItem(String itemId);
  Future<bool> hasStartedItem(String itemId);
  Future<void> setItemPlayed(String itemId, {required bool played});

  Future<MediaServerPlaybackInfo> getPlaybackInfo(
    String itemId, {
    int startTimeTicks = 0,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? maxStreamingBitrate,
    bool forceTranscoding = false,
  });

  Uri playbackUri(String itemId, MediaServerSource source);
  Map<String, String> playbackHeaders();

  Future<String?> fetchSubtitleText(
    String itemId,
    MediaServerSource source,
    MediaStream stream,
  );

  Uri imageUri(
    String itemId, {
    String imageType = 'Primary',
    String? tag,
    int? maxWidth,
  });

  Future<void> downloadItem(
    String itemId,
    String savePath, {
    Uri? sourceUri,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  });

  Uri downloadUri(String itemId);

  Uri compatibleDownloadUri({
    required String itemId,
    required String mediaSourceId,
    required int maxVideoBitrate,
    required int maxWidth,
    required int maxHeight,
    int audioBitrate = 192000,
  });

  Map<String, String> downloadHeaders();

  Future<void> reportPlaybackStarted({
    required String itemId,
    required String mediaSourceId,
    required String playSessionId,
    required int positionTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String playMethod = 'Transcode',
  });

  Future<void> reportPlaybackProgress({
    required String itemId,
    required String mediaSourceId,
    required String playSessionId,
    required int positionTicks,
    required bool isPaused,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? volumeLevel,
    String playMethod = 'Transcode',
  });

  Future<void> reportPlaybackStopped({
    required String itemId,
    required String mediaSourceId,
    required String playSessionId,
    required int positionTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String playMethod = 'Transcode',
  });
}
