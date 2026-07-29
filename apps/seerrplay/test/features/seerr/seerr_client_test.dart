import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/seerr/data/seerr_client.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

void main() {
  late _RecordingAdapter adapter;
  late SeerrClient client;

  setUp(() {
    adapter = _RecordingAdapter();
    client = SeerrClient(
      baseUrl: 'http://seerr.local/',
      dio: Dio()..httpClientAdapter = adapter,
    );
  });

  test('local login captures connect.sid and reuses it for me', () async {
    adapter.enqueue(
      body: {'id': 7, 'email': 'user@example.com', 'username': 'Ada'},
      headers: {
        'set-cookie': [
          'connect.sid=s%3Aabc.signature; Path=/; HttpOnly; SameSite=Lax',
        ],
      },
    );
    adapter.enqueue(body: {'id': 7, 'email': 'user@example.com'});

    final user = await client.loginLocal(
      email: ' user@example.com ',
      password: 'secret',
    );
    await client.me();

    expect(user.displayName, 'Ada');
    expect(client.sessionCookie, 'connect.sid=s%3Aabc.signature');
    expect(adapter.requests.first.uri.path, '/api/v1/auth/local');
    expect(adapter.requests.first.data, {
      'email': 'user@example.com',
      'password': 'secret',
    });
    expect(
      adapter.requests.last.headers['Cookie'],
      'connect.sid=s%3Aabc.signature',
    );
  });

  test('Jellyfin login sends optional server discovery fields', () async {
    adapter.enqueue(body: {'id': 1, 'email': 'jf@example.com'});

    await client.loginMediaServer(
      username: 'jelly',
      password: 'fish',
      hostname: 'https://jellyfin.local',
      email: 'jf@example.com',
      serverType: 2,
    );

    expect(adapter.requests.single.uri.path, '/api/v1/auth/jellyfin');
    expect(adapter.requests.single.data, {
      'username': 'jelly',
      'password': 'fish',
      'hostname': 'https://jellyfin.local',
      'email': 'jf@example.com',
      'serverType': 2,
    });
  });

  test('Plex login sends the OAuth token to Seerr', () async {
    adapter.enqueue(body: {'id': 2, 'email': 'plex@example.com'});

    await client.loginPlex(authToken: 'plex-token');

    expect(adapter.requests.single.uri.path, '/api/v1/auth/plex');
    expect(adapter.requests.single.data, {'authToken': 'plex-token'});
  });

  test('finds Jellyfin links exposed by available media', () async {
    adapter.enqueue(
      body: {
        'pageInfo': {'results': 2},
        'results': [
          {
            'id': 1,
            'mediaUrl':
                'https://media.example.com/jellyfin/web/index.html#!/details?id=abc',
          },
          {
            'id': 2,
            'mediaUrl': null,
            'mediaUrl4k':
                'http://192.168.1.20:8096/web/index.html#!/details?id=def',
          },
        ],
      },
    );

    final urls = await client.availableMediaUrls();

    expect(urls, hasLength(2));
    expect(urls.first.host, 'media.example.com');
    expect(urls.last.port, 8096);
    expect(adapter.requests.single.uri.path, '/api/v1/media');
    expect(
      adapter.requests.single.uri.queryParameters['filter'],
      'allavailable',
    );
  });

  test('trending tolerates mixed and incomplete media payloads', () async {
    adapter.enqueue(
      body: {
        'page': 2,
        'totalPages': '4',
        'totalResults': 2,
        'results': [
          {
            'id': 10,
            'mediaType': 'movie',
            'title': 'Arrival',
            'voteAverage': '8.1',
            'releaseDate': '2016-11-11',
            'mediaInfo': {'id': 8, 'tmdbId': 10, 'status': 5},
          },
          {'id': '11', 'mediaType': 'tv', 'name': 'Dark'},
          null,
        ],
      },
    );

    final page = await client.trending(
      page: 2,
      language: 'fr',
      mediaType: SeerrMediaType.movie,
      timeWindow: 'week',
    );

    expect(page.totalPages, 4);
    expect(page.results.map((media) => media.title), ['Arrival', 'Dark']);
    expect(
      page.results.first.mediaInfo?.availability,
      SeerrAvailability.available,
    );
    expect(adapter.requests.single.queryParameters, {
      'page': 2,
      'language': 'fr',
      'mediaType': 'movie',
      'timeWindow': 'week',
    });
  });

  test('search and details decode movie and TV variants', () async {
    adapter.enqueue(
      body: {
        'results': [
          {'id': 1, 'mediaType': 'person'},
        ],
      },
    );
    adapter.enqueue(
      body: {
        'id': 22,
        'title': 'Dune',
        'budget': 165000000,
        'revenue': 400000000,
        'externalIds': {'imdbId': 'tt1160419'},
        'releases': {
          'results': [
            {
              'iso_3166_1': 'FR',
              'release_dates': [
                {
                  'certification': '12',
                  'release_date': '2021-09-15T00:00:00.000Z',
                  'type': 3,
                },
                {
                  'certification': '',
                  'release_date': '2022-01-12T00:00:00.000Z',
                  'type': 5,
                },
              ],
            },
          ],
        },
        'genres': [
          {'id': 878, 'name': 'Science Fiction'},
        ],
        'credits': {
          'cast': [
            {'id': 1, 'name': 'Actor', 'character': 'Hero'},
          ],
        },
        'mediaInfo': {
          'id': 4,
          'tmdbId': 22,
          'status': 4,
          'seasons': [
            {'seasonNumber': 1, 'status': 5},
            {'seasonNumber': 2, 'status': 2},
          ],
        },
      },
    );
    adapter.enqueue(
      body: {
        'id': 33,
        'name': 'Severance',
        'episodeRunTime': [55],
        'contentRatings': {
          'results': [
            {'iso_3166_1': 'FR', 'rating': '16'},
          ],
        },
        'seasons': [
          {'id': 2, 'seasonNumber': 1, 'name': 'Season 1', 'episodeCount': 9},
        ],
      },
    );

    final search = await client.search(query: ' Que justice soit faite ');
    final movie = await client.movieDetails(22, language: 'fr');
    final tv = await client.tvDetails(33);

    expect(search.results.single.type, SeerrMediaType.person);
    expect(adapter.requests.first.uri.queryParameters, {
      'query': 'Que justice soit faite',
      'page': '1',
    });
    expect(
      adapter.requests.first.uri.query,
      contains('query=Que%20justice%20soit%20faite'),
    );
    expect(movie.genres.single.name, 'Science Fiction');
    expect(movie.cast.single.character, 'Hero');
    expect(movie.budget, 165000000);
    expect(movie.revenue, 400000000);
    expect(movie.imdbId, 'tt1160419');
    expect(movie.certificationFor('FR'), '12');
    expect(movie.theatricalReleaseFor('FR'), DateTime.utc(2021, 9, 15));
    expect(movie.videoReleaseFor('FR'), DateTime.utc(2022, 1, 12));
    expect(
      movie.mediaInfo?.seasons.first.availability,
      SeerrAvailability.available,
    );
    expect(tv.runtimeMinutes, 55);
    expect(tv.certificationFor('FR'), '16');
    expect(tv.seasons.single.episodeCount, 9);
  });

  test('loads combined movie and Rotten Tomatoes TV ratings', () async {
    adapter.enqueue(
      body: {
        'rt': {
          'criticsScore': 91,
          'audienceScore': 84,
          'url': 'https://rottentomatoes.example/movie',
        },
        'imdb': {'criticsScore': 8.2, 'url': 'https://imdb.example/title'},
      },
    );
    adapter.enqueue(
      body: {'criticsScore': 95, 'url': 'https://rottentomatoes.example/tv'},
    );

    final movie = await client.ratings(type: SeerrMediaType.movie, mediaId: 22);
    final tv = await client.ratings(type: SeerrMediaType.tv, mediaId: 33);

    expect(movie.rottenTomatoesCriticsScore, 91);
    expect(movie.rottenTomatoesAudienceScore, 84);
    expect(movie.imdbScore, 8.2);
    expect(tv.rottenTomatoesCriticsScore, 95);
    expect(adapter.requests[0].uri.path, '/api/v1/movie/22/ratingscombined');
    expect(adapter.requests[1].uri.path, '/api/v1/tv/33/ratings');
  });

  test('loads person details and combined credits', () async {
    adapter.enqueue(
      body: {
        'id': 42,
        'name': 'Ada Actor',
        'birthday': '1985-03-04',
        'knownForDepartment': 'Acting',
        'biography': 'A biography.',
        'placeOfBirth': 'Paris, France',
        'profilePath': '/ada.jpg',
        'alsoKnownAs': ['A. Actor'],
      },
    );
    adapter.enqueue(
      body: {
        'id': 42,
        'cast': [
          {
            'id': 7,
            'mediaType': 'movie',
            'title': 'The Film',
            'character': 'Alex',
            'popularity': 12.5,
            'releaseDate': '2024-05-10',
            'mediaInfo': {
              'id': 8,
              'tmdbId': 7,
              'status': 5,
              'jellyfinMediaId': 'jf-7',
            },
          },
        ],
        'crew': [
          {
            'id': 9,
            'mediaType': 'tv',
            'name': 'The Series',
            'job': 'Director',
            'department': 'Directing',
            'firstAirDate': '2022-01-03',
          },
        ],
      },
    );

    final person = await client.personDetails(42, language: 'fr');
    final credits = await client.personCredits(42, language: 'fr');

    expect(person.name, 'Ada Actor');
    expect(person.birthday, DateTime(1985, 3, 4));
    expect(person.alsoKnownAs, ['A. Actor']);
    expect(credits.cast.single.character, 'Alex');
    expect(
      credits.cast.single.mediaInfo?.availability,
      SeerrAvailability.available,
    );
    expect(credits.crew.single.title, 'The Series');
    expect(credits.crew.single.job, 'Director');
    expect(adapter.requests[0].uri.path, '/api/v1/person/42');
    expect(adapter.requests[1].uri.path, '/api/v1/person/42/combined_credits');
    expect(adapter.requests[0].queryParameters, {'language': 'fr'});
    expect(adapter.requests[1].queryParameters, {'language': 'fr'});
  });

  test('movie and all-season TV requests use Seerr request contract', () async {
    adapter.enqueue(body: {'id': 90, 'status': 2});
    adapter.enqueue(body: {'id': 91, 'status': 1});

    final movie = await client.requestMovie(550);
    final tv = await client.requestTvAllSeasons(1399);

    expect(movie.status, SeerrRequestStatus.approved);
    expect(tv.status, SeerrRequestStatus.pendingApproval);
    expect(adapter.requests[0].data, {'mediaType': 'movie', 'mediaId': 550});
    expect(adapter.requests[1].data, {
      'mediaType': 'tv',
      'mediaId': 1399,
      'seasons': 'all',
    });
  });

  test('deletes a request with the Seerr request endpoint', () async {
    adapter.enqueue(body: {});

    await client.deleteRequest(90);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.uri.path, '/api/v1/request/90');
  });

  test('temporarily caches metadata and supports explicit refresh', () async {
    adapter.enqueue(
      body: {
        'results': [
          {'id': 10, 'mediaType': 'movie', 'title': 'Cached movie'},
        ],
      },
    );

    final first = await client.discoverMovies();
    final cached = await client.discoverMovies();

    expect(first.results.single.title, 'Cached movie');
    expect(cached.results.single.title, 'Cached movie');
    expect(adapter.requests, hasLength(1));

    adapter.enqueue(
      body: {
        'results': [
          {'id': 11, 'mediaType': 'movie', 'title': 'Fresh movie'},
        ],
      },
    );
    client.clearCache();
    final refreshed = await client.discoverMovies();

    expect(refreshed.results.single.title, 'Fresh movie');
    expect(adapter.requests, hasLength(2));
  });

  test('does not cache user request statuses', () async {
    adapter.enqueue(
      body: {
        'pageInfo': {'results': 1},
        'results': [
          {'id': 42, 'type': 'movie', 'status': 1},
        ],
      },
    );
    adapter.enqueue(
      body: {
        'pageInfo': {'results': 1},
        'results': [
          {'id': 42, 'type': 'movie', 'status': 2},
        ],
      },
    );

    final pending = await client.userRequests(7);
    final approved = await client.userRequests(7);

    expect(pending.results.single.status, SeerrRequestStatus.pendingApproval);
    expect(approved.results.single.status, SeerrRequestStatus.approved);
    expect(adapter.requests, hasLength(2));
  });

  test('loads one request status without caching it', () async {
    adapter.enqueue(
      body: {
        'id': 42,
        'type': 'movie',
        'status': 2,
        'media': {
          'id': 8,
          'tmdbId': 550,
          'status': 3,
          'downloadStatus': [
            {
              'title': 'Movie',
              'status': 'downloading',
              'size': 100,
              'sizeLeft': 60,
            },
          ],
        },
      },
    );
    adapter.enqueue(
      body: {
        'id': 42,
        'type': 'movie',
        'status': 2,
        'media': {'id': 8, 'tmdbId': 550, 'status': 5},
      },
    );

    final downloading = await client.mediaRequest(42);
    final available = await client.mediaRequest(42);

    expect(downloading.media?.downloadStatus.single.progress, .4);
    expect(available.media?.availability, SeerrAvailability.available);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.uri.path, '/api/v1/request/42');
  });

  test('loads popular movies, genres, and recommendations', () async {
    adapter.enqueue(
      body: {
        'results': [
          {'id': 10, 'mediaType': 'movie', 'title': 'Movie'},
        ],
      },
    );
    adapter.enqueue(
      body: [
        {'id': 28, 'name': 'Action'},
      ],
    );
    adapter.enqueue(
      body: {
        'results': [
          {'id': 11, 'mediaType': 'movie', 'title': 'Recommended'},
        ],
      },
    );

    final movies = await client.discoverMovies();
    final genres = await client.movieGenres(language: 'fr');
    final recommendations = await client.recommendations(
      type: SeerrMediaType.movie,
      mediaId: 10,
      language: 'fr',
    );

    expect(movies.results.single.title, 'Movie');
    expect(genres.single.name, 'Action');
    expect(recommendations.results.single.title, 'Recommended');
    expect(adapter.requests[0].uri.path, '/api/v1/discover/movies');
    expect(adapter.requests[0].queryParameters, isNot(contains('language')));
    expect(adapter.requests[1].uri.path, '/api/v1/genres/movie');
    expect(adapter.requests[2].uri.path, '/api/v1/movie/10/recommendations');
  });

  test('loads dashboard settings and user requests', () async {
    adapter.enqueue(body: {'hideAvailable': true, 'hideBlocklisted': false});
    adapter.enqueue(
      body: {
        'hideAvailable': false,
        'hideBlocklisted': true,
        'discoverRegion': 'FR',
        'jellyfinExternalHost': 'https://jellyfin.example.com',
        'jellyfinServerName': 'Living room',
        'mediaServerLogin': true,
        'localLogin': true,
        'mediaServerType': 2,
      },
    );
    adapter.enqueue(
      body: {
        'pageInfo': {'results': 1},
        'results': [
          {
            'id': 42,
            'type': 'movie',
            'status': 2,
            'media': {
              'id': 8,
              'tmdbId': 550,
              'status': 3,
              'downloadStatus': [
                {
                  'title': 'Movie',
                  'status': 'downloading',
                  'size': 100,
                  'sizeLeft': 25,
                },
              ],
            },
          },
        ],
      },
    );

    final settings = await client.mainSettings();
    final publicSettings = await client.publicSettings();
    final requests = await client.userRequests(7, take: 10);

    expect(settings.hideAvailable, isTrue);
    expect(publicSettings.hideBlocklisted, isTrue);
    expect(publicSettings.discoverRegion, 'FR');
    expect(publicSettings.jellyfinExternalHost, 'https://jellyfin.example.com');
    expect(publicSettings.jellyfinServerName, 'Living room');
    expect(publicSettings.mediaServerLogin, isTrue);
    expect(publicSettings.localLogin, isTrue);
    expect(publicSettings.mediaServerType, 2);
    expect(requests.totalResults, 1);
    expect(requests.results.single.type, SeerrMediaType.movie);
    expect(requests.results.single.media?.downloadStatus.single.progress, .75);
    expect(adapter.requests[1].uri.path, '/api/v1/settings/public');
    expect(adapter.requests[2].uri.path, '/api/v1/user/7/requests');
  });

  test('loads regional providers and filters their catalog', () async {
    adapter.enqueue(
      body: [
        {
          'id': 8,
          'name': 'Netflix',
          'displayPriority': 1,
          'logoPath': '/netflix.jpg',
        },
      ],
    );
    adapter.enqueue(
      body: {
        'results': [
          {'id': 12, 'mediaType': 'movie', 'title': 'Provider movie'},
        ],
      },
    );

    final providers = await client.movieWatchProviders('FR');
    final movies = await client.discoverMovies(
      watchRegion: 'FR',
      watchProviderId: 8,
      originalLanguage: 'fr',
    );

    expect(providers.single.name, 'Netflix');
    expect(movies.results.single.title, 'Provider movie');
    expect(adapter.requests[0].queryParameters['watchRegion'], 'FR');
    expect(adapter.requests[1].queryParameters['watchProviders'], '8');
    expect(adapter.requests[1].queryParameters['language'], 'fr');
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<_StubResponse> _responses = [];

  void enqueue({
    required Object body,
    int statusCode = 200,
    Map<String, List<String>> headers = const {},
  }) {
    _responses.add(
      _StubResponse(body: body, statusCode: statusCode, headers: headers),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...response.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _StubResponse {
  const _StubResponse({
    required this.body,
    required this.statusCode,
    required this.headers,
  });

  final Object body;
  final int statusCode;
  final Map<String, List<String>> headers;
}
