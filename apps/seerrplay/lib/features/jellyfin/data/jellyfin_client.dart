import 'package:dio/dio.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

const _defaultFields = <String>[
  'Overview',
  'ProviderIds',
  'PrimaryImageAspectRatio',
];

String buildJellyfinAuthorizationHeader({
  required String client,
  required String device,
  required String deviceId,
  required String version,
  String? token,
}) {
  String escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  final values = <String, String>{
    'Client': client,
    'Device': device,
    'DeviceId': deviceId,
    'Version': version,
    if (token != null && token.isNotEmpty) 'Token': token,
  };
  final parameters = values.entries
      .map((entry) => '${entry.key}="${escape(entry.value)}"')
      .join(', ');
  return 'MediaBrowser $parameters';
}

class JellyfinClient implements MediaServerClient {
  JellyfinClient({
    required this.baseUrl,
    required this.deviceId,
    Dio? dio,
    this.serverType = MediaServerType.jellyfin,
    this.clientName = 'SeerrPlay',
    this.deviceName = 'SeerrPlay',
    this.clientVersion = '1.0.0',
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      connectTimeout: _dio.options.connectTimeout ?? const Duration(seconds: 4),
      sendTimeout: _dio.options.sendTimeout ?? const Duration(seconds: 4),
      receiveTimeout: _dio.options.receiveTimeout ?? const Duration(seconds: 6),
    );
  }

  @override
  final Uri baseUrl;
  final String deviceId;
  @override
  final MediaServerType serverType;
  final String clientName;
  final String deviceName;
  final String clientVersion;
  final Dio _dio;

  MediaServerSession? _session;

  MediaServerSession? get session => _session;

  @override
  bool get supportsTranscodedDownloads => true;

  void restoreSession(MediaServerSession session) {
    _session = session;
  }

  void clearSession() {
    _session = null;
  }

  Future<MediaServerSession> authenticateByName({
    required String username,
    required String password,
  }) async {
    final response = await _dio.postUri<Object?>(
      _uri(const ['Users', 'AuthenticateByName']),
      data: {'Username': username, 'Pw': password},
      options: Options(headers: _headers()),
    );
    final session = MediaServerSession.fromJson(_responseMap(response.data));
    if (session.accessToken.isEmpty || session.user.id.isEmpty) {
      throw FormatException(
        'Invalid ${serverType.displayName} authentication response',
      );
    }
    _session = session;
    return session;
  }

  @override
  Future<MediaServerItemsPage> getResumeItems({
    int startIndex = 0,
    int limit = 20,
    List<String> includeItemTypes = const ['Movie', 'Episode'],
  }) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        ['Users', session.user.id, 'Items', 'Resume'],
        query: {
          'StartIndex': '$startIndex',
          'Limit': '$limit',
          'Recursive': 'true',
          'MediaTypes': 'Video',
          'IncludeItemTypes': includeItemTypes.join(','),
          'Fields': _defaultFields.join(','),
          'EnableUserData': 'true',
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
          'EnableTotalRecordCount': 'true',
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItemsPage.fromJson(_responseMap(response.data));
  }

  @override
  Future<MediaServerItemsPage> getLibraryItems({
    int startIndex = 0,
    int limit = 200,
    String searchTerm = '',
    List<String> includeItemTypes = const ['Movie', 'Series', 'Video'],
  }) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        ['Users', session.user.id, 'Items'],
        query: {
          'StartIndex': '$startIndex',
          'Limit': '$limit',
          'Recursive': 'true',
          'IncludeItemTypes': includeItemTypes.join(','),
          'SortBy': 'SortName',
          'SortOrder': 'Ascending',
          'Fields': _defaultFields.join(','),
          'EnableUserData': 'true',
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
          'EnableTotalRecordCount': 'true',
          if (searchTerm.trim().isNotEmpty) 'SearchTerm': searchTerm.trim(),
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItemsPage.fromJson(_responseMap(response.data));
  }

  @override
  Future<MediaServerItemsPage> getNextUp({
    int startIndex = 0,
    int limit = 20,
  }) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        const ['Shows', 'NextUp'],
        query: {
          'UserId': session.user.id,
          'StartIndex': '$startIndex',
          'Limit': '$limit',
          'Fields': _defaultFields.join(','),
          'EnableUserData': 'true',
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
          'EnableTotalRecordCount': 'true',
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItemsPage.fromJson(_responseMap(response.data));
  }

  @override
  Future<MediaServerItemsPage> getRecentlyPlayedEpisodes({
    int startIndex = 0,
    int limit = 100,
  }) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        ['Users', session.user.id, 'Items'],
        query: {
          'StartIndex': '$startIndex',
          'Limit': '$limit',
          'Recursive': 'true',
          'IncludeItemTypes': 'Episode',
          'Filters': 'IsPlayed',
          'SortBy': 'DatePlayed',
          'SortOrder': 'Descending',
          'Fields': _defaultFields.join(','),
          'EnableUserData': 'true',
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
          'EnableTotalRecordCount': 'true',
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItemsPage.fromJson(_responseMap(response.data));
  }

  @override
  Future<List<MediaServerItem>> getSeriesEpisodes(
    String seriesId, {
    int? seasonNumber,
  }) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        ['Users', session.user.id, 'Items'],
        query: {
          'ParentId': seriesId,
          'Recursive': 'true',
          'IncludeItemTypes': 'Episode',
          'SortBy': 'ParentIndexNumber,IndexNumber',
          'SortOrder': 'Ascending',
          'Fields': _defaultFields.join(','),
          'EnableUserData': 'true',
          'EnableImageTypes': 'Primary,Backdrop,Thumb',
          'Limit': '1000',
          'EnableTotalRecordCount': 'true',
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    final items = MediaServerItemsPage.fromJson(
      _responseMap(response.data),
    ).items;
    if (seasonNumber == null) return items;
    return items
        .where((episode) => episode.parentIndexNumber == seasonNumber)
        .toList(growable: false);
  }

  @override
  Future<MediaServerItem> getItemDetails(String itemId) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(['Users', session.user.id, 'Items', itemId]),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItem.fromJson(_responseMap(response.data));
  }

  @override
  Future<MediaServerItem> getPlayableItem(String itemId) async {
    final item = await getItemDetails(itemId);
    if (item.type != 'Series') return item;
    final nextUp = await _getSeriesNextUp(item.id);
    if (nextUp.items.isNotEmpty) return nextUp.items.first;
    final episodes = await _getFirstSeriesEpisode(item.id);
    if (episodes.items.isNotEmpty) return episodes.items.first;
    throw const FormatException('No episode is available for this series.');
  }

  @override
  Future<bool> hasStartedItem(String itemId) async {
    final item = await getItemDetails(itemId);
    final userData = item.userData;
    if (userData?.played == true ||
        (userData?.playbackPositionTicks ?? 0) > 0) {
      return true;
    }
    if (item.type != 'Series') return false;
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        ['Users', session.user.id, 'Items'],
        query: {
          'ParentId': item.id,
          'Recursive': 'true',
          'IncludeItemTypes': 'Episode',
          'Filters': 'IsPlayed',
          'Limit': '1',
          'EnableTotalRecordCount': 'true',
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItemsPage.fromJson(
          _responseMap(response.data),
        ).totalRecordCount >
        0;
  }

  @override
  Future<void> setItemPlayed(String itemId, {required bool played}) async {
    final session = _requireSession();
    final uri = _uri(['Users', session.user.id, 'PlayedItems', itemId]);
    final options = Options(headers: _headers(token: session.accessToken));
    if (played) {
      await _dio.postUri<Object?>(uri, options: options);
    } else {
      await _dio.deleteUri<Object?>(uri, options: options);
    }
  }

  Future<MediaServerItemsPage> _getSeriesNextUp(String seriesId) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        const ['Shows', 'NextUp'],
        query: {
          'UserId': session.user.id,
          'SeriesId': seriesId,
          'Limit': '1',
          'Fields': _defaultFields.join(','),
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItemsPage.fromJson(_responseMap(response.data));
  }

  Future<MediaServerItemsPage> _getFirstSeriesEpisode(String seriesId) async {
    final session = _requireSession();
    final response = await _dio.getUri<Object?>(
      _uri(
        ['Users', session.user.id, 'Items'],
        query: {
          'ParentId': seriesId,
          'Recursive': 'true',
          'IncludeItemTypes': 'Episode',
          'SortBy': 'ParentIndexNumber,IndexNumber',
          'SortOrder': 'Ascending',
          'Limit': '1',
          'Fields': _defaultFields.join(','),
        },
      ),
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerItemsPage.fromJson(_responseMap(response.data));
  }

  @override
  Future<MediaServerPlaybackInfo> getPlaybackInfo(
    String itemId, {
    int startTimeTicks = 0,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? maxStreamingBitrate,
    bool forceTranscoding = false,
  }) async {
    final session = _requireSession();
    final request = <String, Object?>{
      'UserId': session.user.id,
      'StartTimeTicks': startTimeTicks,
      'AudioStreamIndex': audioStreamIndex,
      'SubtitleStreamIndex': subtitleStreamIndex,
      'MaxStreamingBitrate': ?maxStreamingBitrate,
      'EnableDirectPlay': !forceTranscoding,
      'EnableDirectStream': !forceTranscoding,
      'EnableTranscoding': true,
      'AllowVideoStreamCopy': true,
      'AllowAudioStreamCopy': true,
      'DeviceProfile': _nativeVideoProfile(maxStreamingBitrate ?? 120000000),
    };
    final response = await _dio.postUri<Object?>(
      _uri(
        ['Items', itemId, 'PlaybackInfo'],
        query: {
          'UserId': session.user.id,
          'StartTimeTicks': '$startTimeTicks',
          if (audioStreamIndex != null) 'AudioStreamIndex': '$audioStreamIndex',
          if (subtitleStreamIndex != null)
            'SubtitleStreamIndex': '$subtitleStreamIndex',
          if (maxStreamingBitrate != null)
            'MaxStreamingBitrate': '$maxStreamingBitrate',
          'EnableDirectPlay': '${!forceTranscoding}',
          'EnableDirectStream': '${!forceTranscoding}',
          'EnableTranscoding': 'true',
          'IsPlayback': 'true',
          'AutoOpenLiveStream': 'true',
        },
      ),
      data: request,
      options: Options(headers: _headers(token: session.accessToken)),
    );
    return MediaServerPlaybackInfo.fromJson(_responseMap(response.data));
  }

  @override
  Uri playbackUri(String itemId, MediaServerSource source) {
    final session = _requireSession();
    final transcodingUrl = source.transcodingUrl;
    if (transcodingUrl != null && transcodingUrl.isNotEmpty) {
      final relative = Uri.parse(transcodingUrl);
      return baseUrl.replace(
        pathSegments: [
          ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
          ...relative.pathSegments.where((segment) => segment.isNotEmpty),
        ],
        queryParameters: {
          ...relative.queryParameters,
          if (!relative.queryParameters.containsKey('api_key'))
            'api_key': session.accessToken,
        },
      );
    }
    return _uri(
      ['Videos', itemId, 'stream'],
      query: {
        'Static': 'true',
        'MediaSourceId': source.id,
        'api_key': session.accessToken,
      },
    );
  }

  @override
  Map<String, String> playbackHeaders() {
    final session = _requireSession();
    return _headers(token: session.accessToken);
  }

  @override
  Uri imageUri(
    String itemId, {
    String imageType = 'Primary',
    String? tag,
    int? maxWidth,
  }) {
    return _uri(
      ['Items', itemId, 'Images', imageType],
      query: {
        if (tag?.isNotEmpty == true) 'tag': tag!,
        if (maxWidth != null) 'maxWidth': '$maxWidth',
        'quality': '90',
      },
    );
  }

  @override
  Future<void> downloadItem(
    String itemId,
    String savePath, {
    Uri? sourceUri,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final session = _requireSession();
    await _dio.downloadUri(
      sourceUri ?? _uri(['Items', itemId, 'Download']),
      savePath,
      options: Options(headers: _headers(token: session.accessToken)),
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  @override
  Uri downloadUri(String itemId) => _uri(['Items', itemId, 'Download']);

  @override
  Uri compatibleDownloadUri({
    required String itemId,
    required String mediaSourceId,
    required int maxVideoBitrate,
    required int maxWidth,
    required int maxHeight,
    int audioBitrate = 192000,
  }) {
    final session = _requireSession();
    return _uri(
      ['Videos', itemId, 'stream.mp4'],
      query: {
        'Static': 'false',
        'UserId': session.user.id,
        'DeviceId': deviceId,
        'MediaSourceId': mediaSourceId,
        'VideoCodec': 'h264',
        'AudioCodec': 'aac',
        'VideoBitrate': '$maxVideoBitrate',
        'AudioBitrate': '$audioBitrate',
        'MaxWidth': '$maxWidth',
        'MaxHeight': '$maxHeight',
        'MaxAudioChannels': '2',
        'TranscodingProtocol': 'http',
        'EnableAutoStreamCopy': 'false',
        'AllowVideoStreamCopy': 'false',
        'AllowAudioStreamCopy': 'false',
        'RequireAvc': 'true',
        'SubtitleMethod': 'Encode',
        'api_key': session.accessToken,
      },
    );
  }

  @override
  Map<String, String> downloadHeaders() {
    final session = _requireSession();
    return _headers(token: session.accessToken);
  }

  @override
  Future<void> reportPlaybackStarted({
    required String itemId,
    required String mediaSourceId,
    required String playSessionId,
    required int positionTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String playMethod = 'Transcode',
  }) {
    return _reportPlayback(
      'Playing',
      itemId: itemId,
      mediaSourceId: mediaSourceId,
      playSessionId: playSessionId,
      positionTicks: positionTicks,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
      playMethod: playMethod,
    );
  }

  @override
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
  }) {
    return _reportPlayback(
      'Playing/Progress',
      itemId: itemId,
      mediaSourceId: mediaSourceId,
      playSessionId: playSessionId,
      positionTicks: positionTicks,
      isPaused: isPaused,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
      volumeLevel: volumeLevel,
      playMethod: playMethod,
    );
  }

  @override
  Future<void> reportPlaybackStopped({
    required String itemId,
    required String mediaSourceId,
    required String playSessionId,
    required int positionTicks,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    String playMethod = 'Transcode',
  }) {
    return _reportPlayback(
      'Playing/Stopped',
      itemId: itemId,
      mediaSourceId: mediaSourceId,
      playSessionId: playSessionId,
      positionTicks: positionTicks,
      audioStreamIndex: audioStreamIndex,
      subtitleStreamIndex: subtitleStreamIndex,
      playMethod: playMethod,
    );
  }

  Future<void> _reportPlayback(
    String path, {
    required String itemId,
    required String mediaSourceId,
    required String playSessionId,
    required int positionTicks,
    bool isPaused = false,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? volumeLevel,
    String playMethod = 'Transcode',
  }) async {
    final session = _requireSession();
    await _dio.postUri<Object?>(
      _uri(['Sessions', ...path.split('/')]),
      data: {
        'ItemId': itemId,
        'MediaSourceId': mediaSourceId,
        'PlaySessionId': playSessionId,
        'PositionTicks': positionTicks,
        'IsPaused': isPaused,
        'PlayMethod': playMethod,
        'AudioStreamIndex': ?audioStreamIndex,
        'SubtitleStreamIndex': ?subtitleStreamIndex,
        'VolumeLevel': ?volumeLevel,
      },
      options: Options(headers: _headers(token: session.accessToken)),
    );
  }

  MediaServerSession _requireSession() {
    final currentSession = _session;
    if (currentSession == null || currentSession.accessToken.isEmpty) {
      throw StateError('A media server session is required');
    }
    return currentSession;
  }

  Uri _uri(List<String> segments, {Map<String, String>? query}) {
    return baseUrl.replace(
      pathSegments: [
        ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...segments,
      ],
      queryParameters: query,
      fragment: '',
    );
  }

  Map<String, String> _headers({String? token}) {
    return {
      'Authorization': buildJellyfinAuthorizationHeader(
        client: clientName,
        device: deviceName,
        deviceId: deviceId,
        version: clientVersion,
        token: token,
      ),
      if (token != null && token.isNotEmpty) 'X-Emby-Token': token,
    };
  }
}

Map<String, Object> _nativeVideoProfile(int maxStreamingBitrate) => {
  'MaxStreamingBitrate': maxStreamingBitrate,
  'DirectPlayProfiles': [
    {
      'Container': 'mp4,m4v,mov',
      'Type': 'Video',
      'VideoCodec': 'h264,hevc',
      'AudioCodec': 'aac,mp3,ac3,eac3',
    },
  ],
  'TranscodingProfiles': [
    {
      'Container': 'ts',
      'Type': 'Video',
      'Protocol': 'hls',
      'AudioCodec': 'aac',
      'VideoCodec': 'h264',
      'Context': 'Streaming',
      'MaxAudioChannels': '6',
      'MinSegments': 2,
      'BreakOnNonKeyFrames': true,
    },
  ],
  'SubtitleProfiles': [
    {'Format': 'vtt', 'Method': 'Encode'},
    {'Format': 'srt', 'Method': 'Encode'},
    {'Format': 'ass', 'Method': 'Encode'},
    {'Format': 'ssa', 'Method': 'Encode'},
    {'Format': 'pgs', 'Method': 'Encode'},
    {'Format': 'sub', 'Method': 'Encode'},
  ],
};

Map<String, dynamic> _responseMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Invalid MediaBrowser response');
}
