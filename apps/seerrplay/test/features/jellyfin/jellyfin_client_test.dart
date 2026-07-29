import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/jellyfin/data/jellyfin_client.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';

void main() {
  test('builds a valid escaped MediaBrowser authorization header', () {
    expect(
      buildJellyfinAuthorizationHeader(
        client: 'Seer"TV',
        device: r'iPhone\Charles',
        deviceId: 'device-1',
        version: '1.0.0',
        token: 'token-1',
      ),
      r'MediaBrowser Client="Seer\"TV", Device="iPhone\\Charles", DeviceId="device-1", Version="1.0.0", Token="token-1"',
    );
  });

  test('authenticates and retains the user session', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'AccessToken': 'access-token',
        'ServerId': 'server-1',
        'User': {'Id': 'user-1', 'Name': 'Charles'},
      }),
    ]);
    final client = _client(adapter);

    final session = await client.authenticateByName(
      username: 'Charles',
      password: 'secret',
    );

    expect(session.accessToken, 'access-token');
    expect(session.user.id, 'user-1');
    expect(client.session, same(session));
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/jellyfin/Users/AuthenticateByName');
    expect(request.headers['Authorization'], contains('MediaBrowser '));
    expect(request.headers.containsKey('X-Emby-Token'), isFalse);
    expect(request.data, {'Username': 'Charles', 'Pw': 'secret'});
  });

  test('loads playback rows and details with the token', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'Items': [
          {
            'Id': 'resume-1',
            'Name': 'Movie',
            'Type': 'Movie',
            'UserData': {'PlaybackPositionTicks': 500},
          },
        ],
        'TotalRecordCount': 1,
      }),
      _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0}),
      _jsonResponse({
        'Items': [
          {
            'Id': 'episode-1',
            'Name': 'Episode',
            'Type': 'Episode',
            'SeriesId': 'series-1',
            'UserData': {'LastPlayedDate': '2026-07-22T20:30:00Z'},
          },
        ],
        'TotalRecordCount': 1,
      }),
      _jsonResponse({
        'Id': 'movie/1',
        'Name': 'Movie',
        'Type': 'Movie',
        'ProviderIds': {'Tmdb': '10'},
      }),
    ]);
    final client = _client(adapter)
      ..restoreSession(
        const MediaServerSession(
          accessToken: 'access-token',
          user: MediaServerUser(id: 'user 1', name: 'Charles'),
        ),
      );

    final resume = await client.getResumeItems(limit: 7);
    final nextUp = await client.getNextUp();
    final recentlyPlayed = await client.getRecentlyPlayedEpisodes();
    final details = await client.getItemDetails('movie/1');

    expect(resume.items.single.userData?.playbackPositionTicks, 500);
    expect(nextUp.items, isEmpty);
    expect(
      recentlyPlayed.items.single.userData?.lastPlayedDate,
      DateTime.utc(2026, 7, 22, 20, 30),
    );
    expect(details.providerIds['Tmdb'], '10');

    final resumeRequest = adapter.requests[0];
    expect(resumeRequest.uri.path, '/jellyfin/Users/user%201/Items/Resume');
    expect(resumeRequest.uri.queryParameters['Limit'], '7');
    expect(
      resumeRequest.uri.queryParameters['IncludeItemTypes'],
      'Movie,Episode',
    );
    expect(resumeRequest.headers['X-Emby-Token'], 'access-token');
    expect(
      resumeRequest.headers['Authorization'],
      contains('Token="access-token"'),
    );

    expect(adapter.requests[1].uri.path, '/jellyfin/Shows/NextUp');
    expect(adapter.requests[1].uri.queryParameters['UserId'], 'user 1');
    expect(adapter.requests[2].uri.path, '/jellyfin/Users/user%201/Items');
    expect(adapter.requests[2].uri.queryParameters['SortBy'], 'DatePlayed');
    expect(adapter.requests[2].uri.queryParameters['Filters'], 'IsPlayed');
    expect(
      adapter.requests[3].uri.path,
      '/jellyfin/Users/user%201/Items/movie%2F1',
    );
  });

  test('loads the full Jellyfin catalog without TMDB metadata', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'Items': [
          {
            'Id': 'documentary-1',
            'Name': 'Private documentary',
            'Type': 'Video',
            'ImageTags': {'Primary': 'poster-tag'},
          },
          {'Id': 'anime-1', 'Name': 'Unlisted anime', 'Type': 'Series'},
        ],
        'TotalRecordCount': 2,
        'StartIndex': 0,
      }),
    ]);
    final client = _client(adapter)
      ..restoreSession(
        const MediaServerSession(
          accessToken: 'access-token',
          user: MediaServerUser(id: 'user-1', name: 'Charles'),
        ),
      );

    final page = await client.getLibraryItems(searchTerm: 'unlisted');

    expect(page.items, hasLength(2));
    expect(page.items.first.providerIds, isEmpty);
    expect(page.items.first.primaryImageTag, 'poster-tag');
    final request = adapter.requests.single;
    expect(request.uri.path, '/jellyfin/Users/user-1/Items');
    expect(
      request.uri.queryParameters['IncludeItemTypes'],
      'Movie,Series,Video',
    );
    expect(request.uri.queryParameters['SearchTerm'], 'unlisted');
  });

  test('rejects user calls without a session', () {
    final client = _client(_QueueAdapter(const []));
    expect(client.getResumeItems, throwsStateError);
  });

  test('negotiates playback and builds the transcoded stream', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'PlaySessionId': 'play-1',
        'MediaSources': [
          {
            'Id': 'source-1',
            'TranscodingUrl':
                '/Videos/movie/master.m3u8?MediaSourceId=source-1',
          },
        ],
      }),
    ]);
    final client = _client(adapter)
      ..restoreSession(
        const MediaServerSession(
          accessToken: 'access-token',
          user: MediaServerUser(id: 'user-1', name: 'Charles'),
        ),
      );

    final playback = await client.getPlaybackInfo(
      'movie-1',
      audioStreamIndex: 2,
      subtitleStreamIndex: 4,
      maxStreamingBitrate: 10000000,
      forceTranscoding: true,
    );
    final uri = client.playbackUri('movie-1', playback.mediaSources.single);

    expect(playback.playSessionId, 'play-1');
    expect(
      adapter.requests.single.uri.path,
      '/jellyfin/Items/movie-1/PlaybackInfo',
    );
    expect(uri.path, '/jellyfin/Videos/movie/master.m3u8');
    expect(uri.queryParameters['api_key'], 'access-token');
    expect(
      adapter.requests.single.uri.queryParameters['AudioStreamIndex'],
      '2',
    );
    expect(
      adapter.requests.single.uri.queryParameters['SubtitleStreamIndex'],
      '4',
    );
    expect(adapter.requests.single.data['MaxStreamingBitrate'], 10000000);
    expect(adapter.requests.single.data['EnableDirectPlay'], isFalse);
  });

  test('lets Jellyfin choose default playback settings', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'MediaSources': [
          {'Id': 'source-1'},
        ],
      }),
    ]);
    final client = _client(adapter)
      ..restoreSession(
        const MediaServerSession(
          accessToken: 'access-token',
          user: MediaServerUser(id: 'user-1', name: 'Charles'),
        ),
      );

    await client.getPlaybackInfo('movie-1');

    final request = adapter.requests.single;
    expect(request.uri.queryParameters, isNot(contains('AudioStreamIndex')));
    expect(request.uri.queryParameters, isNot(contains('SubtitleStreamIndex')));
    expect(request.uri.queryParameters, isNot(contains('MaxStreamingBitrate')));
    expect(request.data, isNot(contains('MaxStreamingBitrate')));
    expect(request.data['EnableDirectPlay'], isTrue);
  });

  test('detects started media so its request can be hidden', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'Id': 'movie-1',
        'Name': 'Movie',
        'Type': 'Movie',
        'UserData': {'Played': false, 'PlaybackPositionTicks': 1200},
      }),
    ]);
    final client = _client(adapter)
      ..restoreSession(
        const MediaServerSession(
          accessToken: 'access-token',
          user: MediaServerUser(id: 'user-1', name: 'Charles'),
        ),
      );

    expect(await client.hasStartedItem('movie-1'), isTrue);
  });

  test('loads season episodes and updates watched state', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'Items': [
          {
            'Id': 'episode-1',
            'Name': 'Episode 1',
            'Type': 'Episode',
            'ParentIndexNumber': 2,
            'IndexNumber': 1,
            'UserData': {'Played': true},
          },
        ],
        'TotalRecordCount': 1,
      }),
      _jsonResponse(const {}),
      _jsonResponse(const {}),
    ]);
    final client = _client(adapter)
      ..restoreSession(
        const MediaServerSession(
          accessToken: 'access-token',
          user: MediaServerUser(id: 'user-1', name: 'Charles'),
        ),
      );

    final episodes = await client.getSeriesEpisodes(
      'series-1',
      seasonNumber: 2,
    );
    await client.setItemPlayed('episode-1', played: true);
    await client.setItemPlayed('episode-1', played: false);

    expect(episodes.single.userData?.played, isTrue);
    expect(adapter.requests[0].uri.queryParameters['ParentId'], 'series-1');
    expect(adapter.requests[0].uri.queryParameters['EnableUserData'], 'true');
    expect(adapter.requests[1].method, 'POST');
    expect(
      adapter.requests[1].uri.path,
      '/jellyfin/Users/user-1/PlayedItems/episode-1',
    );
    expect(adapter.requests[2].method, 'DELETE');
  });

  test('downloads an authorized item to a local file', () async {
    final adapter = _QueueAdapter([
      ResponseBody.fromBytes(
        const [1, 2, 3, 4],
        200,
        headers: {
          Headers.contentLengthHeader: ['4'],
          Headers.contentTypeHeader: ['video/mp4'],
        },
      ),
    ]);
    final client = _client(adapter)
      ..restoreSession(
        const MediaServerSession(
          accessToken: 'access-token',
          user: MediaServerUser(id: 'user-1', name: 'Charles'),
        ),
      );
    final directory = await Directory.systemTemp.createTemp(
      'seerrplay-download-test',
    );
    final path = '${directory.path}/movie.mp4';

    await client.downloadItem('movie-1', path);

    expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
    expect(
      adapter.requests.single.uri.path,
      '/jellyfin/Items/movie-1/Download',
    );
    expect(adapter.requests.single.headers['X-Emby-Token'], 'access-token');
    await directory.delete(recursive: true);
  });
}

JellyfinClient _client(_QueueAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return JellyfinClient(
    baseUrl: Uri.parse('https://media.example.test/jellyfin/'),
    deviceId: 'device-1',
    deviceName: 'iPhone',
    dio: dio,
  );
}

ResponseBody _jsonResponse(Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<ResponseBody> responses;
  final List<RequestOptions> requests = [];
  var _responseIndex = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responses[_responseIndex++];
  }

  @override
  void close({bool force = false}) {}
}
