import 'package:dio/dio.dart';

import '../domain/seerr_models.dart';

typedef SeerrSessionChanged = void Function(String? sessionCookie);

class SeerrClient {
  SeerrClient({
    required String baseUrl,
    Dio? dio,
    String? sessionCookie,
    this.onSessionChanged,
  }) : _dio = dio ?? Dio(),
       _sessionCookie = _normalizeSessionCookie(sessionCookie) {
    _dio.options = _dio.options.copyWith(
      baseUrl: _normalizeBaseUrl(baseUrl),
      connectTimeout: _dio.options.connectTimeout ?? const Duration(seconds: 4),
      sendTimeout: _dio.options.sendTimeout ?? const Duration(seconds: 4),
      receiveTimeout: _dio.options.receiveTimeout ?? const Duration(seconds: 6),
      headers: <String, dynamic>{
        ..._dio.options.headers,
        Headers.acceptHeader: Headers.jsonContentType,
      },
    );
  }

  final Dio _dio;
  final SeerrSessionChanged? onSessionChanged;
  final Map<String, _SeerrCacheEntry> _responseCache = {};
  final Map<String, Future<Response<Object?>>> _pendingCachedRequests = {};
  String? _sessionCookie;
  int _cacheGeneration = 0;

  static const _shortCacheDuration = Duration(minutes: 2);
  static const _longCacheDuration = Duration(minutes: 10);

  String? get sessionCookie => _sessionCookie;

  set sessionCookie(String? value) {
    _setSession(_normalizeSessionCookie(value));
  }

  void clearCache() {
    _cacheGeneration++;
    _responseCache.clear();
    _pendingCachedRequests.clear();
  }

  Future<SeerrUser> loginLocal({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Object?>(
      '/auth/local',
      data: <String, dynamic>{'email': email.trim(), 'password': password},
    );
    _captureSession(response);
    return SeerrUser.fromJson(_responseMap(response));
  }

  Future<SeerrUser> loginMediaServer({
    required String username,
    required String password,
    String? hostname,
    String? email,
    int? serverType,
  }) async {
    final data = <String, dynamic>{
      'username': username.trim(),
      'password': password,
      if (hostname?.trim().isNotEmpty == true) 'hostname': hostname!.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
    };
    if (serverType != null) data['serverType'] = serverType;
    final response = await _dio.post<Object?>('/auth/jellyfin', data: data);
    _captureSession(response);
    return SeerrUser.fromJson(_responseMap(response));
  }

  Future<SeerrUser> loginPlex({required String authToken}) async {
    final response = await _dio.post<Object?>(
      '/auth/plex',
      data: <String, dynamic>{'authToken': authToken},
    );
    _captureSession(response);
    return SeerrUser.fromJson(_responseMap(response));
  }

  Future<SeerrUser> me() async {
    final response = await _cachedGet(
      '/auth/me',
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrUser.fromJson(_responseMap(response));
  }

  Future<SeerrMainSettings> mainSettings() async {
    final response = await _cachedGet(
      '/settings/main',
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrMainSettings.fromJson(_responseMap(response));
  }

  Future<SeerrMainSettings> publicSettings() async {
    final response = await _cachedGet(
      '/settings/public',
      duration: _shortCacheDuration,
    );
    return SeerrMainSettings.fromJson(_responseMap(response));
  }

  Future<SeerrUserSettings> userSettings(int userId) async {
    final response = await _cachedGet(
      '/user/$userId/settings/main',
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrUserSettings.fromJson(_responseMap(response));
  }

  Future<List<SeerrWatchProvider>> movieWatchProviders(String region) {
    return _watchProviders('/watchproviders/movies', region);
  }

  Future<List<SeerrWatchProvider>> tvWatchProviders(String region) {
    return _watchProviders('/watchproviders/tv', region);
  }

  Future<SeerrUserRequests> userRequests(
    int userId, {
    int take = 10,
    int skip = 0,
  }) async {
    final response = await _dio.get<Object?>(
      '/user/$userId/requests',
      queryParameters: {'take': take, 'skip': skip},
      options: _authenticatedOptions(),
    );
    return SeerrUserRequests.fromJson(_responseMap(response));
  }

  Future<List<Uri>> availableMediaUrls({int take = 50}) async {
    final response = await _dio.get<Object?>(
      '/media',
      queryParameters: {
        'take': take,
        'skip': 0,
        'filter': 'allavailable',
        'sort': 'mediaAdded',
      },
      options: _authenticatedOptions(),
    );
    final results = _responseMap(response)['results'];
    if (results is! List) return const [];
    return results
        .whereType<Map>()
        .expand(
          (media) =>
              [media['mediaUrl'], media['mediaUrl4k']].whereType<String>(),
        )
        .map(Uri.tryParse)
        .whereType<Uri>()
        .where(
          (uri) =>
              const {'http', 'https'}.contains(uri.scheme) &&
              uri.host.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<SeerrMediaRequest> mediaRequest(int requestId) async {
    final response = await _dio.get<Object?>(
      '/request/$requestId',
      options: _authenticatedOptions(),
    );
    return SeerrMediaRequest.fromJson(_responseMap(response));
  }

  Future<SeerrPage<SeerrMedia>> trending({
    int page = 1,
    String? language,
    SeerrMediaType? mediaType,
    String timeWindow = 'day',
  }) async {
    final response = await _cachedGet(
      '/discover/trending',
      queryParameters: <String, dynamic>{
        'page': page,
        if (language?.isNotEmpty == true) 'language': language,
        if (mediaType != null && mediaType != SeerrMediaType.unknown)
          'mediaType': mediaType.apiValue,
        'timeWindow': timeWindow,
      },
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrPage.fromJson(_responseMap(response), SeerrMedia.fromJson);
  }

  Future<SeerrPage<SeerrMedia>> discoverMovies({
    int page = 1,
    String? originalLanguage,
    int? genreId,
    String? watchRegion,
    int? watchProviderId,
  }) {
    final query = <String, dynamic>{};
    if (originalLanguage?.isNotEmpty == true) {
      query['language'] = originalLanguage;
    }
    if (watchRegion != null) query['watchRegion'] = watchRegion;
    if (watchProviderId != null) {
      query['watchProviders'] = '$watchProviderId';
    }
    return _discover(
      genreId == null ? '/discover/movies' : '/discover/movies/genre/$genreId',
      page: page,
      query: query,
    );
  }

  Future<SeerrPage<SeerrMedia>> discoverTv({
    int page = 1,
    String? originalLanguage,
    int? genreId,
    String? watchRegion,
    int? watchProviderId,
  }) {
    final query = <String, dynamic>{};
    if (originalLanguage?.isNotEmpty == true) {
      query['language'] = originalLanguage;
    }
    if (watchRegion != null) query['watchRegion'] = watchRegion;
    if (watchProviderId != null) {
      query['watchProviders'] = '$watchProviderId';
    }
    return _discover(
      genreId == null ? '/discover/tv' : '/discover/tv/genre/$genreId',
      page: page,
      query: query,
    );
  }

  Future<List<SeerrGenre>> movieGenres({String? language}) {
    return _genres('/genres/movie', language: language);
  }

  Future<List<SeerrGenre>> tvGenres({String? language}) {
    return _genres('/genres/tv', language: language);
  }

  Future<SeerrPage<SeerrMedia>> recommendations({
    required SeerrMediaType type,
    required int mediaId,
    String? language,
  }) {
    return _related(type, mediaId, 'recommendations', language);
  }

  Future<SeerrPage<SeerrMedia>> similar({
    required SeerrMediaType type,
    required int mediaId,
    String? language,
  }) {
    return _related(type, mediaId, 'similar', language);
  }

  Future<SeerrPage<SeerrMedia>> search({
    required String query,
    int page = 1,
    String? language,
    CancelToken? cancelToken,
  }) async {
    final encodedQuery = Uri.encodeComponent(query.trim());
    final encodedLanguage = language?.trim().isNotEmpty == true
        ? '&language=${Uri.encodeComponent(language!.trim())}'
        : '';
    final response = await _dio.get<Object?>(
      '/search?query=$encodedQuery&page=$page$encodedLanguage',
      options: _authenticatedOptions(),
      cancelToken: cancelToken,
    );
    return SeerrPage.fromJson(_responseMap(response), SeerrMedia.fromJson);
  }

  Future<SeerrMovieDetails> movieDetails(
    int movieId, {
    String? language,
  }) async {
    final response = await _cachedGet(
      '/movie/$movieId',
      queryParameters: <String, dynamic>{
        if (language?.isNotEmpty == true) 'language': language,
      },
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrMovieDetails.fromJson(_responseMap(response));
  }

  Future<SeerrTvDetails> tvDetails(int tvId, {String? language}) async {
    final response = await _cachedGet(
      '/tv/$tvId',
      queryParameters: <String, dynamic>{
        if (language?.isNotEmpty == true) 'language': language,
      },
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrTvDetails.fromJson(_responseMap(response));
  }

  Future<SeerrPersonDetails> personDetails(
    int personId, {
    String? language,
  }) async {
    final response = await _cachedGet(
      '/person/$personId',
      queryParameters: <String, dynamic>{
        if (language?.isNotEmpty == true) 'language': language,
      },
      duration: _longCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrPersonDetails.fromJson(_responseMap(response));
  }

  Future<SeerrPersonCredits> personCredits(
    int personId, {
    String? language,
  }) async {
    final response = await _cachedGet(
      '/person/$personId/combined_credits',
      queryParameters: <String, dynamic>{
        if (language?.isNotEmpty == true) 'language': language,
      },
      duration: _longCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrPersonCredits.fromJson(_responseMap(response));
  }

  Future<SeerrRatings> ratings({
    required SeerrMediaType type,
    required int mediaId,
  }) async {
    final response = await _cachedGet(
      type == SeerrMediaType.movie
          ? '/movie/$mediaId/ratingscombined'
          : '/tv/$mediaId/ratings',
      duration: _longCacheDuration,
      options: _authenticatedOptions(),
    );
    final json = _responseMap(response);
    return type == SeerrMediaType.movie
        ? SeerrRatings.fromMovieJson(json)
        : SeerrRatings.fromTvJson(json);
  }

  Future<SeerrSeason> tvSeasonDetails(
    int tvId,
    int seasonNumber, {
    String? language,
  }) async {
    final response = await _cachedGet(
      '/tv/$tvId/season/$seasonNumber',
      queryParameters: {if (language?.isNotEmpty == true) 'language': language},
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrSeason.fromJson(_responseMap(response));
  }

  Future<SeerrMediaRequest> requestMovie(int movieId) {
    return _createRequest(<String, dynamic>{
      'mediaType': SeerrMediaType.movie.apiValue,
      'mediaId': movieId,
    });
  }

  Future<SeerrMediaRequest> requestTvAllSeasons(int tvId) {
    return _createRequest(<String, dynamic>{
      'mediaType': SeerrMediaType.tv.apiValue,
      'mediaId': tvId,
      'seasons': 'all',
    });
  }

  Future<SeerrMediaRequest> requestTvSeasons(int tvId, List<int> seasons) {
    return _createRequest(<String, dynamic>{
      'mediaType': SeerrMediaType.tv.apiValue,
      'mediaId': tvId,
      'seasons': seasons,
    });
  }

  Future<SeerrMediaRequest> retryRequest(int requestId) async {
    final response = await _dio.post<Object?>(
      '/request/$requestId/retry',
      options: _authenticatedOptions(),
    );
    clearCache();
    return SeerrMediaRequest.fromJson(_responseMap(response));
  }

  Future<void> deleteRequest(int requestId) async {
    await _dio.delete<Object?>(
      '/request/$requestId',
      options: _authenticatedOptions(),
    );
    clearCache();
  }

  Future<SeerrMediaRequest> _createRequest(Map<String, dynamic> data) async {
    final response = await _dio.post<Object?>(
      '/request',
      data: data,
      options: _authenticatedOptions(),
    );
    clearCache();
    return SeerrMediaRequest.fromJson(_responseMap(response));
  }

  Future<SeerrPage<SeerrMedia>> _discover(
    String path, {
    required int page,
    Map<String, dynamic> query = const {},
  }) async {
    final response = await _cachedGet(
      path,
      queryParameters: {'page': page, ...query},
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrPage.fromJson(_responseMap(response), SeerrMedia.fromJson);
  }

  Future<List<SeerrWatchProvider>> _watchProviders(
    String path,
    String region,
  ) async {
    final response = await _cachedGet(
      path,
      queryParameters: {'watchRegion': region},
      duration: _longCacheDuration,
      options: _authenticatedOptions(),
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid provider list');
    }
    return data
        .whereType<Map>()
        .map(
          (item) =>
              SeerrWatchProvider.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<SeerrGenre>> _genres(String path, {String? language}) async {
    final response = await _cachedGet(
      path,
      queryParameters: {if (language?.isNotEmpty == true) 'language': language},
      duration: _longCacheDuration,
      options: _authenticatedOptions(),
    );
    final data = response.data;
    if (data is! List) throw const FormatException('Invalid genre list');
    return data
        .whereType<Map>()
        .map((item) => SeerrGenre.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<SeerrPage<SeerrMedia>> _related(
    SeerrMediaType type,
    int mediaId,
    String relation,
    String? language,
  ) async {
    final response = await _cachedGet(
      '/${type.apiValue}/$mediaId/$relation',
      queryParameters: {if (language?.isNotEmpty == true) 'language': language},
      duration: _shortCacheDuration,
      options: _authenticatedOptions(),
    );
    return SeerrPage.fromJson(_responseMap(response), SeerrMedia.fromJson);
  }

  Options? _authenticatedOptions() {
    final cookie = _sessionCookie;
    if (cookie == null) return null;
    return Options(headers: <String, dynamic>{'Cookie': cookie});
  }

  Future<Response<Object?>> _cachedGet(
    String path, {
    required Duration duration,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final cacheKey = _cacheKey(path, queryParameters);
    final cached = _responseCache[cacheKey];
    final now = DateTime.now();
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return cached.response;
    }
    _responseCache.remove(cacheKey);

    // Multiple rails often request the same Seerr resource during one frame.
    // Share the in-flight Future so refreshes do not fan out duplicate calls.
    final pending = _pendingCachedRequests[cacheKey];
    if (pending != null) return pending;

    final generation = _cacheGeneration;
    final request = _dio.get<Object?>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
    _pendingCachedRequests[cacheKey] = request;
    try {
      final response = await request;
      // A logout or explicit refresh increments the generation. A response
      // that started before that boundary must not repopulate stale cache data.
      if (generation == _cacheGeneration) {
        _responseCache[cacheKey] = _SeerrCacheEntry(
          response: response,
          expiresAt: DateTime.now().add(duration),
        );
      }
      return response;
    } finally {
      if (identical(_pendingCachedRequests[cacheKey], request)) {
        _pendingCachedRequests.remove(cacheKey);
      }
    }
  }

  String _cacheKey(String path, Map<String, dynamic>? queryParameters) {
    final query = queryParameters?.entries.toList(growable: false) ?? const [];
    final sorted = [...query]
      ..sort((left, right) => left.key.compareTo(right.key));
    return [
      path,
      for (final entry in sorted)
        '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent('${entry.value}')}',
    ].join('&');
  }

  void _captureSession(Response<Object?> response) {
    for (final header in response.headers['set-cookie'] ?? const []) {
      final match = RegExp(
        r'(?:^|,\s*)(connect\.sid=[^;\s,]+)',
      ).firstMatch(header);
      if (match != null) {
        _setSession(match.group(1));
        return;
      }
    }
  }

  void _setSession(String? value) {
    if (_sessionCookie == value) return;
    clearCache();
    _sessionCookie = value;
    onSessionChanged?.call(value);
  }

  static Map<String, dynamic> _responseMap(Response<Object?> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry('$key', value));
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Seerr returned an invalid JSON object.',
    );
  }

  static String _normalizeBaseUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/v1')) return url;
    return '$url/api/v1';
  }

  static String? _normalizeSessionCookie(String? value) {
    final cookie = value?.trim();
    if (cookie == null || cookie.isEmpty) return null;
    if (cookie.startsWith('connect.sid=')) return cookie.split(';').first;
    return 'connect.sid=${cookie.split(';').first}';
  }
}

class _SeerrCacheEntry {
  const _SeerrCacheEntry({required this.response, required this.expiresAt});

  final Response<Object?> response;
  final DateTime expiresAt;
}
