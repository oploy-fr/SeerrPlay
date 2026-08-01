import 'dart:async';

import 'package:dio/dio.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

class PlexPin {
  const PlexPin({
    required this.id,
    required this.code,
    required this.authenticationUrl,
    this.authToken,
  });

  final int id;
  final String code;
  final Uri authenticationUrl;
  final String? authToken;
}

class PlexConnection {
  const PlexConnection({
    required this.uri,
    required this.local,
    required this.relay,
  });

  final Uri uri;
  final bool local;
  final bool relay;
}

class PlexResource {
  const PlexResource({
    required this.name,
    required this.clientIdentifier,
    required this.connections,
  });

  final String name;
  final String clientIdentifier;
  final List<PlexConnection> connections;

  PlexConnection? get preferredConnection {
    final remoteHttps = connections
        .where((connection) => !connection.local && !connection.relay)
        .where((connection) => connection.uri.scheme == 'https')
        .firstOrNull;
    return remoteHttps ??
        connections
            .where((connection) => !connection.relay)
            .where((connection) => connection.uri.scheme == 'https')
            .firstOrNull ??
        connections.where((connection) => !connection.relay).firstOrNull ??
        connections.firstOrNull;
  }
}

class PlexAuthentication {
  PlexAuthentication({required this.clientIdentifier, Dio? dio})
    : _dio = dio ?? Dio();

  static const _product = 'SeerrPlay';
  final String clientIdentifier;
  final Dio _dio;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'X-Plex-Product': _product,
    'X-Plex-Client-Identifier': clientIdentifier,
    'X-Plex-Platform': 'Flutter',
    'X-Plex-Version': '1.0.0',
  };

  Future<PlexPin> createPin() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://plex.tv/api/v2/pins',
      queryParameters: {'strong': 'true'},
      options: Options(headers: _headers),
    );
    final data = response.data ?? const {};
    final id = _asInt(data['id']);
    final code = _asString(data['code']);
    if (id == null || code == null || code.isEmpty) {
      throw const FormatException('Invalid Plex PIN response.');
    }
    final parameters = Uri(
      queryParameters: {
        'clientID': clientIdentifier,
        'code': code,
        'context[device][product]': _product,
      },
    ).query;
    final authUrl = Uri.https(
      'app.plex.tv',
      '/auth',
    ).replace(fragment: '?$parameters');
    return PlexPin(id: id, code: code, authenticationUrl: authUrl);
  }

  Future<String?> pollPin(int pinId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://plex.tv/api/v2/pins/$pinId',
      options: Options(headers: _headers),
    );
    return _asString(response.data?['authToken']);
  }

  Future<String> waitForToken(
    int pinId, {
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final token = await pollPin(pinId);
      if (token?.isNotEmpty == true) return token!;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw TimeoutException('Plex authentication timed out.');
  }

  Future<List<PlexResource>> resources(String token) async {
    final response = await _dio.get<List<dynamic>>(
      'https://plex.tv/api/v2/resources',
      queryParameters: {'includeHttps': '1', 'includeRelay': '1'},
      options: Options(headers: {..._headers, 'X-Plex-Token': token}),
    );
    return (response.data ?? const [])
        .whereType<Map>()
        .where((resource) {
          final provides = _asString(resource['provides']) ?? '';
          return provides.split(',').contains('server');
        })
        .map((resource) {
          final values = Map<String, dynamic>.from(resource);
          final connections = values['connections'];
          return PlexResource(
            name: _asString(values['name']) ?? 'Plex',
            clientIdentifier: _asString(values['clientIdentifier']) ?? '',
            connections: connections is List
                ? connections
                      .whereType<Map>()
                      .map((connection) {
                        final values = Map<String, dynamic>.from(connection);
                        return PlexConnection(
                          uri: Uri.parse(_asString(values['uri']) ?? ''),
                          local: values['local'] == true,
                          relay: values['relay'] == true,
                        );
                      })
                      .where((connection) => connection.uri.host.isNotEmpty)
                      .toList()
                : const [],
          );
        })
        .where((resource) => resource.clientIdentifier.isNotEmpty)
        .toList(growable: false);
  }
}

class PlexClient implements MediaServerClient {
  PlexClient({
    required this.baseUrl,
    required this.deviceId,
    required this.accessToken,
    required this.machineIdentifier,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  @override
  final Uri baseUrl;
  final String deviceId;
  final String accessToken;
  final String machineIdentifier;
  final Dio _dio;
  final Map<String, int> _durationMilliseconds = {};

  @override
  MediaServerType get serverType => MediaServerType.plex;

  @override
  bool get supportsTranscodedDownloads => false;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'X-Plex-Token': accessToken,
    'X-Plex-Product': 'SeerrPlay',
    'X-Plex-Client-Identifier': deviceId,
    'X-Plex-Platform': 'Flutter',
    'X-Plex-Version': '1.0.0',
  };

  @override
  Future<MediaServerItemsPage> getResumeItems({
    int startIndex = 0,
    int limit = 20,
    List<String> includeItemTypes = const ['Movie', 'Episode'],
  }) {
    return _items(
      '/hubs/home/continueWatching',
      startIndex: startIndex,
      limit: limit,
    );
  }

  @override
  Future<MediaServerItemsPage> getLibraryItems({
    int startIndex = 0,
    int limit = 200,
    String searchTerm = '',
    List<String> includeItemTypes = const ['Movie', 'Series', 'Video'],
  }) {
    if (searchTerm.trim().isNotEmpty) {
      return _items(
        '/hubs/search',
        startIndex: startIndex,
        limit: limit,
        query: {'query': searchTerm.trim()},
      );
    }
    return _items('/library/all', startIndex: startIndex, limit: limit);
  }

  @override
  Future<MediaServerItemsPage> getNextUp({int startIndex = 0, int limit = 20}) {
    return _items('/library/onDeck', startIndex: startIndex, limit: limit);
  }

  @override
  Future<MediaServerItemsPage> getRecentlyPlayedEpisodes({
    int startIndex = 0,
    int limit = 100,
  }) {
    return _items(
      '/status/sessions/history/all',
      startIndex: startIndex,
      limit: limit,
      query: {'sort': 'viewedAt:desc', 'type': '4'},
    );
  }

  @override
  Future<List<MediaServerItem>> getSeriesEpisodes(
    String seriesId, {
    int? seasonNumber,
  }) async {
    final page = await _items(
      '/library/metadata/$seriesId/allLeaves',
      startIndex: 0,
      limit: 1000,
    );
    if (seasonNumber == null) return page.items;
    return page.items
        .where((episode) => episode.parentIndexNumber == seasonNumber)
        .toList(growable: false);
  }

  @override
  Future<MediaServerItem> getItemDetails(String itemId) async {
    final response = await _get('/library/metadata/$itemId', {
      'includeGuids': '1',
      'includeUserState': '1',
    });
    final metadata = _metadata(response);
    if (metadata.isEmpty) {
      throw const FormatException('Plex media was not found.');
    }
    return _mapItem(metadata.first);
  }

  @override
  Future<MediaServerItem> getPlayableItem(String itemId) async {
    final item = await getItemDetails(itemId);
    if (item.type != 'Series') return item;
    final page = await _items(
      '/library/metadata/$itemId/allLeaves',
      startIndex: 0,
      limit: 1,
    );
    if (page.items.isEmpty) {
      throw const FormatException('No episode is available for this series.');
    }
    return page.items.first;
  }

  @override
  Future<bool> hasStartedItem(String itemId) async {
    final item = await getItemDetails(itemId);
    if (item.userData?.played == true ||
        (item.userData?.playbackPositionTicks ?? 0) > 0) {
      return true;
    }
    if (item.type != 'Series') return false;
    final leaves = await _items(
      '/library/metadata/$itemId/allLeaves',
      startIndex: 0,
      limit: 1,
      query: {'viewCount>': '0'},
    );
    return leaves.items.isNotEmpty;
  }

  @override
  Future<void> setItemPlayed(String itemId, {required bool played}) async {
    await _dio.getUri<Object?>(
      _uri(played ? '/:/scrobble' : '/:/unscrobble', {
        'key': itemId,
        'identifier': 'com.plexapp.plugins.library',
      }),
      options: Options(headers: _headers, responseType: ResponseType.plain),
    );
  }

  @override
  Future<MediaServerPlaybackInfo> getPlaybackInfo(
    String itemId, {
    int startTimeTicks = 0,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? maxStreamingBitrate,
    bool forceTranscoding = false,
  }) async {
    final response = await _get('/library/metadata/$itemId', {
      'includeGuids': '1',
      'includeUserState': '1',
    });
    final metadata = _metadata(response);
    if (metadata.isEmpty) {
      throw const FormatException('No Plex video source is available.');
    }
    final rawItem = metadata.first;
    final durationMs = _asInt(rawItem['duration']) ?? 0;
    _durationMilliseconds[itemId] = durationMs;
    final media = _asList(rawItem['Media']).whereType<Map>().firstOrNull;
    final mediaValues = media == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(media);
    final part = _asList(mediaValues['Part']).whereType<Map>().firstOrNull;
    if (part == null) {
      throw const FormatException('No Plex video part is available.');
    }
    final partValues = Map<String, dynamic>.from(part);
    if (audioStreamIndex != null || subtitleStreamIndex != null) {
      await _selectStreams(
        _asString(partValues['id']) ?? '',
        audioStreamIndex,
        subtitleStreamIndex,
      );
    }
    final streams = _asList(partValues['Stream'])
        .whereType<Map>()
        .map((stream) => _mapStream(Map<String, dynamic>.from(stream)))
        .toList(growable: false);
    // Plex direct play cannot reliably switch embedded tracks or enforce a
    // bitrate. Those choices deliberately move the session to Universal HLS.
    final directPlay = !forceTranscoding && maxStreamingBitrate == null;
    final metadataPath =
        _asString(rawItem['key']) ?? '/library/metadata/$itemId';
    final source = MediaServerSource(
      id: _asString(partValues['id']) ?? itemId,
      name: _asString(mediaValues['videoResolution']),
      container:
          _asString(partValues['container']) ??
          _asString(mediaValues['container']),
      runTimeTicks: durationMs * 10000,
      sizeBytes: _asInt(partValues['size']),
      bitrate: (_asInt(mediaValues['bitrate']) ?? 0) * 1000,
      supportsDirectPlay: directPlay,
      supportsDirectStream: true,
      mediaStreams: streams,
      defaultAudioStreamIndex: streams
          .where((stream) => stream.type == MediaStreamType.audio)
          .where((stream) => stream.isDefault)
          .firstOrNull
          ?.index,
      defaultSubtitleStreamIndex: streams
          .where((stream) => stream.type == MediaStreamType.subtitle)
          .where((stream) => stream.isDefault)
          .firstOrNull
          ?.index,
      directStreamPath: _asString(partValues['key']),
      metadataPath: metadataPath,
      transcodingUrl: directPlay
          ? null
          : _transcodeUri(
              metadataPath,
              maxStreamingBitrate: maxStreamingBitrate,
              startTimeTicks: startTimeTicks,
            ).toString(),
    );
    return MediaServerPlaybackInfo(
      mediaSources: [source],
      playSessionId:
          'seerrplay-$deviceId-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  @override
  Uri playbackUri(String itemId, MediaServerSource source) {
    if (source.transcodingUrl?.isNotEmpty == true) {
      return Uri.parse(source.transcodingUrl!);
    }
    final path = source.directStreamPath;
    if (path == null || path.isEmpty) {
      throw const FormatException('Plex returned no playable file.');
    }
    return _uri(path, {'X-Plex-Token': accessToken});
  }

  @override
  Map<String, String> playbackHeaders() => _headers;

  @override
  Future<String?> fetchSubtitleText(
    String itemId,
    MediaServerSource source,
    MediaStream stream,
  ) async {
    final path = stream.deliveryUrl;
    if (path == null || path.isEmpty) return null;
    final response = await _dio.getUri<String>(
      _uri(path, {'X-Plex-Token': accessToken}),
      options: Options(headers: _headers, responseType: ResponseType.plain),
    );
    return response.data;
  }

  @override
  Uri imageUri(
    String itemId, {
    String imageType = 'Primary',
    String? tag,
    int? maxWidth,
  }) {
    final path = tag;
    if (path == null || path.isEmpty) {
      return _uri('/library/metadata/$itemId/thumb', {
        'X-Plex-Token': accessToken,
      });
    }
    return _uri(path, {
      if (maxWidth != null) 'width': '$maxWidth',
      'X-Plex-Token': accessToken,
    });
  }

  @override
  Future<void> downloadItem(
    String itemId,
    String savePath, {
    Uri? sourceUri,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.downloadUri(
      sourceUri ?? downloadUri(itemId),
      savePath,
      options: Options(headers: _headers),
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  @override
  Uri downloadUri(String itemId) {
    throw const FormatException(
      'Load Plex playback information before downloading.',
    );
  }

  @override
  Uri compatibleDownloadUri({
    required String itemId,
    required String mediaSourceId,
    required int maxVideoBitrate,
    required int maxWidth,
    required int maxHeight,
    int audioBitrate = 192000,
  }) {
    throw UnsupportedError(
      'Offline transcoding is not supported by Plex in this version.',
    );
  }

  @override
  Map<String, String> downloadHeaders() => _headers;

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
    return _timeline(
      itemId,
      positionTicks,
      state: 'playing',
      playSessionId: playSessionId,
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
    return _timeline(
      itemId,
      positionTicks,
      state: isPaused ? 'paused' : 'playing',
      playSessionId: playSessionId,
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
    return _timeline(
      itemId,
      positionTicks,
      state: 'stopped',
      playSessionId: playSessionId,
    );
  }

  Future<MediaServerItemsPage> _items(
    String path, {
    required int startIndex,
    required int limit,
    Map<String, String> query = const {},
  }) async {
    final response = await _get(path, {
      ...query,
      'X-Plex-Container-Start': '$startIndex',
      'X-Plex-Container-Size': '$limit',
    });
    final items = _metadata(response).map(_mapItem).toList(growable: false);
    final container = _container(response);
    return MediaServerItemsPage(
      items: items,
      totalRecordCount:
          _asInt(container['totalSize']) ??
          _asInt(container['size']) ??
          items.length,
      startIndex: _asInt(container['offset']) ?? startIndex,
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _dio.getUri<Object?>(
      _uri(path, query),
      options: Options(headers: _headers, responseType: ResponseType.json),
    );
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw const FormatException('Invalid Plex response.');
  }

  List<Map<String, dynamic>> _metadata(Map<String, dynamic> response) {
    final container = _container(response);
    final direct = _asList(container['Metadata']).whereType<Map>();
    final hubs = _asList(container['Hub']).whereType<Map>().expand(
      (hub) => _asList(hub['Metadata']).whereType<Map>(),
    );
    return [
      ...direct,
      ...hubs,
    ].map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
  }

  Map<String, dynamic> _container(Map<String, dynamic> response) {
    final value = response['MediaContainer'];
    return value is Map ? Map<String, dynamic>.from(value) : response;
  }

  MediaServerItem _mapItem(Map<String, dynamic> json) {
    final type = switch (_asString(json['type'])) {
      'movie' => 'Movie',
      'show' => 'Series',
      'episode' => 'Episode',
      _ => 'Video',
    };
    final durationMs = _asInt(json['duration']);
    final viewOffsetMs = _asInt(json['viewOffset']) ?? 0;
    final viewCount = _asInt(json['viewCount']) ?? 0;
    final providerIds = <String, String>{};
    for (final guid in _asList(json['Guid']).whereType<Map>()) {
      final value = _asString(guid['id']);
      if (value == null) continue;
      final separator = value.indexOf('://');
      if (separator > 0) {
        providerIds[value.substring(0, separator)] = value.substring(
          separator + 3,
        );
      }
    }
    return MediaServerItem(
      id: _asString(json['ratingKey']) ?? '',
      name: _asString(json['title']) ?? '',
      type: type,
      overview: _asString(json['summary']),
      runTimeTicks: durationMs == null ? null : durationMs * 10000,
      productionYear: _asInt(json['year']),
      premiereDate: DateTime.tryParse(
        _asString(json['originallyAvailableAt']) ?? '',
      ),
      communityRating:
          _asDouble(json['audienceRating']) ?? _asDouble(json['rating']),
      officialRating: _asString(json['contentRating']),
      seriesName: _asString(json['grandparentTitle']),
      seriesId: _asString(json['grandparentRatingKey']),
      parentIndexNumber: _asInt(json['parentIndex']),
      indexNumber: _asInt(json['index']),
      providerIds: providerIds,
      primaryImagePath: _asString(json['thumb']),
      backdropImagePath: _asString(json['art']),
      userData: MediaServerUserData(
        playbackPositionTicks: viewOffsetMs * 10000,
        playCount: viewCount,
        played: viewCount > 0,
        lastPlayedDate: _unixDate(json['lastViewedAt']),
      ),
    );
  }

  MediaStream _mapStream(Map<String, dynamic> json) {
    final streamType = _asInt(json['streamType']);
    return MediaStream(
      index: _asInt(json['id']) ?? -1,
      type: switch (streamType) {
        1 => MediaStreamType.video,
        2 => MediaStreamType.audio,
        3 => MediaStreamType.subtitle,
        _ => MediaStreamType.unknown,
      },
      displayTitle:
          _asString(json['displayTitle']) ??
          _asString(json['extendedDisplayTitle']),
      title: _asString(json['title']),
      language: _asString(json['language']),
      codec: _asString(json['codec']),
      isDefault: json['selected'] == true || _asInt(json['selected']) == 1,
      isForced: json['forced'] == true || _asInt(json['forced']) == 1,
      isExternal: _asString(json['key'])?.isNotEmpty == true,
      channels: _asInt(json['channels']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      bitRate: _asInt(json['bitrate']),
      deliveryUrl: _asString(json['key']),
    );
  }

  Future<void> _selectStreams(
    String partId,
    int? audioStreamId,
    int? subtitleStreamId,
  ) async {
    if (partId.isEmpty) return;
    await _dio.putUri<Object?>(
      _uri('/library/parts/$partId', {
        if (audioStreamId != null) 'audioStreamID': '$audioStreamId',
        'subtitleStreamID': '${subtitleStreamId ?? 0}',
      }),
      options: Options(headers: _headers),
    );
  }

  Uri _transcodeUri(
    String metadataPath, {
    int? maxStreamingBitrate,
    int startTimeTicks = 0,
  }) {
    return _uri('/video/:/transcode/universal/start.m3u8', {
      'path': metadataPath,
      'mediaIndex': '0',
      'partIndex': '0',
      'protocol': 'hls',
      'directPlay': '0',
      'directStream': '1',
      'fastSeek': '1',
      'copyts': '1',
      'offset': '${startTimeTicks / 10000000}',
      if (maxStreamingBitrate != null)
        'maxVideoBitrate': '${maxStreamingBitrate ~/ 1000}',
      'session': 'seerrplay-$deviceId-${DateTime.now().microsecondsSinceEpoch}',
      'X-Plex-Token': accessToken,
      'X-Plex-Client-Identifier': deviceId,
      'X-Plex-Product': 'SeerrPlay',
    });
  }

  Future<void> _timeline(
    String itemId,
    int positionTicks, {
    required String state,
    required String playSessionId,
  }) async {
    await _dio.getUri<Object?>(
      _uri('/:/timeline', {
        'ratingKey': itemId,
        'key': '/library/metadata/$itemId',
        'state': state,
        'time': '${positionTicks ~/ 10000}',
        'duration': '${_durationMilliseconds[itemId] ?? 0}',
        'playQueueItemID': '0',
        'X-Plex-Session-Identifier': playSessionId,
      }),
      options: Options(headers: _headers),
    );
  }

  Uri _uri(String path, [Map<String, String> query = const {}]) {
    final relative = Uri.parse(path);
    return baseUrl.replace(
      pathSegments: [
        ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...relative.pathSegments.where((segment) => segment.isNotEmpty),
      ],
      queryParameters: query.isEmpty ? null : query,
      fragment: '',
    );
  }
}

List<dynamic> _asList(Object? value) => value is List ? value : const [];
String? _asString(Object? value) => value?.toString();
int? _asInt(Object? value) => switch (value) {
  int value => value,
  num value => value.toInt(),
  String value => int.tryParse(value),
  _ => null,
};
double? _asDouble(Object? value) => switch (value) {
  num value => value.toDouble(),
  String value => double.tryParse(value),
  _ => null,
};
DateTime? _unixDate(Object? value) {
  final seconds = _asInt(value);
  return seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
