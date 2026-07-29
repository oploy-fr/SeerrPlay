enum SeerrMediaType {
  movie('movie'),
  tv('tv'),
  person('person'),
  unknown('unknown');

  const SeerrMediaType(this.apiValue);

  final String apiValue;

  static SeerrMediaType fromJson(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'movie' => movie,
      'tv' => tv,
      'person' => person,
      _ => unknown,
    };
  }
}

enum SeerrAvailability {
  unknown,
  pending,
  processing,
  partiallyAvailable,
  available,
  blocklisted,
  deleted;

  static SeerrAvailability fromJson(Object? value) {
    return switch (_asInt(value)) {
      2 => pending,
      3 => processing,
      4 => partiallyAvailable,
      5 => available,
      6 => blocklisted,
      7 => deleted,
      _ => unknown,
    };
  }
}

enum SeerrRequestStatus {
  unknown,
  pendingApproval,
  approved,
  declined,
  failed,
  completed;

  static SeerrRequestStatus fromJson(Object? value) {
    return switch (_asInt(value)) {
      1 => pendingApproval,
      2 => approved,
      3 => declined,
      4 => failed,
      5 => completed,
      _ => unknown,
    };
  }
}

class SeerrUser {
  const SeerrUser({
    required this.id,
    required this.email,
    this.username,
    this.avatar,
    this.permissions = 0,
    this.requestCount = 0,
  });

  factory SeerrUser.fromJson(Map<String, dynamic> json) {
    return SeerrUser(
      id: _asInt(json['id']),
      email: _asString(json['email']) ?? '',
      username:
          _asString(json['username']) ??
          _asString(json['jellyfinUsername']) ??
          _asString(json['plexUsername']),
      avatar: _asString(json['avatar']),
      permissions: _asInt(json['permissions']),
      requestCount: _asInt(json['requestCount']),
    );
  }

  final int id;
  final String email;
  final String? username;
  final String? avatar;
  final int permissions;
  final int requestCount;

  String get displayName =>
      username?.trim().isNotEmpty == true ? username!.trim() : email;
}

class SeerrMediaInfo {
  const SeerrMediaInfo({
    required this.id,
    required this.tmdbId,
    this.tvdbId,
    this.jellyfinMediaId,
    this.jellyfinMediaId4k,
    this.ratingKey,
    this.ratingKey4k,
    this.downloadStatus = const [],
    this.seasons = const [],
    this.availability = SeerrAvailability.unknown,
  });

  factory SeerrMediaInfo.fromJson(Map<String, dynamic> json) {
    return SeerrMediaInfo(
      id: _asInt(json['id']),
      tmdbId: _asInt(json['tmdbId']),
      tvdbId: _asNullableInt(json['tvdbId']),
      jellyfinMediaId: _asString(json['jellyfinMediaId']),
      jellyfinMediaId4k: _asString(json['jellyfinMediaId4k']),
      ratingKey: _asString(json['ratingKey']),
      ratingKey4k: _asString(json['ratingKey4k']),
      downloadStatus: _decodeList(
        json['downloadStatus'],
        SeerrDownloadItem.fromJson,
      ),
      seasons: _decodeList(json['seasons'], SeerrMediaSeason.fromJson),
      availability: SeerrAvailability.fromJson(json['status']),
    );
  }

  final int id;
  final int tmdbId;
  final int? tvdbId;
  final String? jellyfinMediaId;
  final String? jellyfinMediaId4k;
  final String? ratingKey;
  final String? ratingKey4k;
  final List<SeerrDownloadItem> downloadStatus;
  final List<SeerrMediaSeason> seasons;
  final SeerrAvailability availability;

  String? get mediaServerItemId => ratingKey ?? jellyfinMediaId;
  String? get mediaServerItemId4k => ratingKey4k ?? jellyfinMediaId4k;
}

class SeerrMediaSeason {
  const SeerrMediaSeason({required this.number, required this.availability});

  factory SeerrMediaSeason.fromJson(Map<String, dynamic> json) {
    return SeerrMediaSeason(
      number: _asInt(json['seasonNumber']),
      availability: SeerrAvailability.fromJson(json['status']),
    );
  }

  final int number;
  final SeerrAvailability availability;
}

class SeerrDownloadItem {
  const SeerrDownloadItem({
    required this.title,
    required this.status,
    required this.size,
    required this.sizeLeft,
    this.timeLeft,
  });

  factory SeerrDownloadItem.fromJson(Map<String, dynamic> json) =>
      SeerrDownloadItem(
        title: _asString(json['title']) ?? '',
        status: _asString(json['status']) ?? '',
        size: _asDouble(json['size']),
        sizeLeft: _asDouble(json['sizeLeft']),
        timeLeft: _asString(json['timeLeft']),
      );

  final String title;
  final String status;
  final double size;
  final double sizeLeft;
  final String? timeLeft;

  double? get progress =>
      size <= 0 ? null : ((size - sizeLeft) / size).clamp(0, 1);
}

class SeerrMainSettings {
  const SeerrMainSettings({
    this.hideAvailable = false,
    this.hideBlocklisted = false,
    this.discoverRegion,
    this.streamingRegion,
    this.jellyfinExternalHost,
    this.jellyfinServerName,
    this.mediaServerLogin = false,
    this.localLogin = false,
    this.mediaServerType,
  });

  factory SeerrMainSettings.fromJson(Map<String, dynamic> json) =>
      SeerrMainSettings(
        hideAvailable: json['hideAvailable'] == true,
        hideBlocklisted: json['hideBlocklisted'] == true,
        discoverRegion: _asString(json['discoverRegion']),
        streamingRegion: _asString(json['streamingRegion']),
        jellyfinExternalHost: _asString(json['jellyfinExternalHost']),
        jellyfinServerName: _asString(json['jellyfinServerName']),
        mediaServerLogin: json['mediaServerLogin'] == true,
        localLogin: json['localLogin'] == true,
        mediaServerType: json['mediaServerType'] == null
            ? null
            : _asInt(json['mediaServerType']),
      );

  final bool hideAvailable;
  final bool hideBlocklisted;
  final String? discoverRegion;
  final String? streamingRegion;
  final String? jellyfinExternalHost;
  final String? jellyfinServerName;
  final bool mediaServerLogin;
  final bool localLogin;
  final int? mediaServerType;
}

class SeerrUserSettings {
  const SeerrUserSettings({this.streamingRegion, this.discoverRegion});

  factory SeerrUserSettings.fromJson(Map<String, dynamic> json) =>
      SeerrUserSettings(
        streamingRegion: _asString(json['streamingRegion']),
        discoverRegion: _asString(json['discoverRegion']),
      );

  final String? streamingRegion;
  final String? discoverRegion;
}

class SeerrWatchProvider {
  const SeerrWatchProvider({
    required this.id,
    required this.name,
    required this.displayPriority,
    this.logoPath,
  });

  factory SeerrWatchProvider.fromJson(Map<String, dynamic> json) =>
      SeerrWatchProvider(
        id: _asInt(json['id']),
        name: _asString(json['name']) ?? '',
        displayPriority: _asInt(json['displayPriority'], fallback: 999),
        logoPath: _asString(json['logoPath']),
      );

  final int id;
  final String name;
  final int displayPriority;
  final String? logoPath;
}

class SeerrMedia {
  const SeerrMedia({
    required this.id,
    required this.type,
    required this.title,
    this.originalTitle,
    this.overview = '',
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage = 0,
    this.genreIds = const [],
    this.mediaInfo,
  });

  factory SeerrMedia.fromJson(Map<String, dynamic> json) {
    final title =
        _asString(json['title']) ??
        _asString(json['name']) ??
        _asString(json['originalTitle']) ??
        _asString(json['originalName']) ??
        '';
    final originalTitle =
        _asString(json['originalTitle']) ?? _asString(json['originalName']);
    final date =
        _asString(json['releaseDate']) ?? _asString(json['firstAirDate']);

    return SeerrMedia(
      id: _asInt(json['id']),
      type: SeerrMediaType.fromJson(json['mediaType']),
      title: title,
      originalTitle: originalTitle,
      overview: _asString(json['overview']) ?? '',
      posterPath: _asString(json['posterPath']),
      backdropPath: _asString(json['backdropPath']),
      releaseDate: _asDate(date),
      voteAverage: _asDouble(json['voteAverage']),
      genreIds: _asList(json['genreIds']).map(_asInt).toList(growable: false),
      mediaInfo: _decodeMediaInfoValue(json['mediaInfo']),
    );
  }

  final int id;
  final SeerrMediaType type;
  final String title;
  final String? originalTitle;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final double voteAverage;
  final List<int> genreIds;
  final SeerrMediaInfo? mediaInfo;
}

class SeerrPage<T> {
  const SeerrPage({
    required this.page,
    required this.totalPages,
    required this.totalResults,
    required this.results,
  });

  factory SeerrPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) decode,
  ) {
    final results = _asList(json['results'])
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(decode)
        .toList(growable: false);

    return SeerrPage(
      page: _asInt(json['page'], fallback: 1),
      totalPages: _asInt(json['totalPages'], fallback: 1),
      totalResults: _asInt(json['totalResults'], fallback: results.length),
      results: results,
    );
  }

  final int page;
  final int totalPages;
  final int totalResults;
  final List<T> results;
}

class SeerrGenre {
  const SeerrGenre({required this.id, required this.name});

  factory SeerrGenre.fromJson(Map<String, dynamic> json) {
    return SeerrGenre(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? '',
    );
  }

  final int id;
  final String name;
}

class SeerrCastMember {
  const SeerrCastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
  });

  factory SeerrCastMember.fromJson(Map<String, dynamic> json) {
    return SeerrCastMember(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? '',
      character: _asString(json['character']),
      profilePath: _asString(json['profilePath']),
    );
  }

  final int id;
  final String name;
  final String? character;
  final String? profilePath;
}

class SeerrCrewMember {
  const SeerrCrewMember({
    required this.id,
    required this.name,
    this.job,
    this.department,
    this.profilePath,
  });

  factory SeerrCrewMember.fromJson(Map<String, dynamic> json) {
    return SeerrCrewMember(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? '',
      job: _asString(json['job']),
      department: _asString(json['department']),
      profilePath: _asString(json['profilePath']),
    );
  }

  final int id;
  final String name;
  final String? job;
  final String? department;
  final String? profilePath;
}

class SeerrPersonDetails {
  const SeerrPersonDetails({
    required this.id,
    required this.name,
    required this.biography,
    required this.knownForDepartment,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.profilePath,
    this.imdbId,
    this.homepage,
    this.alsoKnownAs = const [],
  });

  factory SeerrPersonDetails.fromJson(Map<String, dynamic> json) {
    return SeerrPersonDetails(
      id: _asInt(json['id']),
      name: _asString(json['name']) ?? '',
      biography: _asString(json['biography']) ?? '',
      knownForDepartment: _asString(json['knownForDepartment']) ?? '',
      birthday: _asDate(_asString(json['birthday'])),
      deathday: _asDate(_asString(json['deathday'])),
      placeOfBirth: _asString(json['placeOfBirth']),
      profilePath: _asString(json['profilePath']),
      imdbId: _asString(json['imdbId']),
      homepage: _asString(json['homepage']),
      alsoKnownAs: _asList(
        json['alsoKnownAs'],
      ).map(_asString).whereType<String>().toList(growable: false),
    );
  }

  final int id;
  final String name;
  final String biography;
  final String knownForDepartment;
  final DateTime? birthday;
  final DateTime? deathday;
  final String? placeOfBirth;
  final String? profilePath;
  final String? imdbId;
  final String? homepage;
  final List<String> alsoKnownAs;
}

class SeerrPersonCredit {
  const SeerrPersonCredit({
    required this.id,
    required this.type,
    required this.title,
    required this.overview,
    required this.popularity,
    required this.voteAverage,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.character,
    this.department,
    this.job,
    this.mediaInfo,
  });

  factory SeerrPersonCredit.fromJson(Map<String, dynamic> json) {
    return SeerrPersonCredit(
      id: _asInt(json['id']),
      type: SeerrMediaType.fromJson(json['mediaType']),
      title:
          _asString(json['title']) ??
          _asString(json['name']) ??
          _asString(json['originalTitle']) ??
          _asString(json['originalName']) ??
          '',
      overview: _asString(json['overview']) ?? '',
      popularity: _asDouble(json['popularity']),
      voteAverage: _asDouble(json['voteAverage']),
      posterPath: _asString(json['posterPath']),
      backdropPath: _asString(json['backdropPath']),
      releaseDate: _asDate(
        _asString(json['releaseDate']) ?? _asString(json['firstAirDate']),
      ),
      character: _asString(json['character']),
      department: _asString(json['department']),
      job: _asString(json['job']),
      mediaInfo: _decodeMediaInfoValue(json['mediaInfo']),
    );
  }

  final int id;
  final SeerrMediaType type;
  final String title;
  final String overview;
  final double popularity;
  final double voteAverage;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final String? character;
  final String? department;
  final String? job;
  final SeerrMediaInfo? mediaInfo;
}

class SeerrPersonCredits {
  const SeerrPersonCredits({this.cast = const [], this.crew = const []});

  factory SeerrPersonCredits.fromJson(Map<String, dynamic> json) {
    return SeerrPersonCredits(
      cast: _decodeList(json['cast'], SeerrPersonCredit.fromJson),
      crew: _decodeList(json['crew'], SeerrPersonCredit.fromJson),
    );
  }

  final List<SeerrPersonCredit> cast;
  final List<SeerrPersonCredit> crew;
}

class SeerrCompany {
  const SeerrCompany({required this.id, required this.name, this.logoPath});

  factory SeerrCompany.fromJson(Map<String, dynamic> json) => SeerrCompany(
    id: _asInt(json['id']),
    name: _asString(json['name']) ?? '',
    logoPath: _asString(json['logoPath']) ?? _asString(json['logo_path']),
  );

  final int id;
  final String name;
  final String? logoPath;
}

class SeerrRelatedVideo {
  const SeerrRelatedVideo({
    required this.name,
    required this.url,
    this.type,
    this.site,
  });

  factory SeerrRelatedVideo.fromJson(Map<String, dynamic> json) =>
      SeerrRelatedVideo(
        name: _asString(json['name']) ?? 'Video',
        url: _asString(json['url']) ?? '',
        type: _asString(json['type']),
        site: _asString(json['site']),
      );

  final String name;
  final String url;
  final String? type;
  final String? site;
}

class SeerrSeason {
  const SeerrSeason({
    required this.id,
    required this.number,
    required this.name,
    this.episodeCount = 0,
    this.posterPath,
    this.airDate,
    this.overview,
    this.episodes = const [],
  });

  factory SeerrSeason.fromJson(Map<String, dynamic> json) {
    return SeerrSeason(
      id: _asInt(json['id']),
      number: _asInt(json['seasonNumber']),
      name: _asString(json['name']) ?? '',
      episodeCount: _asInt(json['episodeCount']),
      posterPath: _asString(json['posterPath']),
      airDate: _asDate(_asString(json['airDate'])),
      overview: _asString(json['overview']),
      episodes: _decodeList(json['episodes'], SeerrEpisode.fromJson),
    );
  }

  final int id;
  final int number;
  final String name;
  final int episodeCount;
  final String? posterPath;
  final DateTime? airDate;
  final String? overview;
  final List<SeerrEpisode> episodes;
}

class SeerrEpisode {
  const SeerrEpisode({
    required this.id,
    required this.name,
    required this.number,
    required this.seasonNumber,
    this.overview,
    this.airDate,
    this.stillPath,
    this.voteAverage = 0,
  });

  factory SeerrEpisode.fromJson(Map<String, dynamic> json) => SeerrEpisode(
    id: _asInt(json['id']),
    name: _asString(json['name']) ?? '',
    number: _asInt(json['episodeNumber']),
    seasonNumber: _asInt(json['seasonNumber']),
    overview: _asString(json['overview']),
    airDate: _asDate(_asString(json['airDate'])),
    stillPath: _asString(json['stillPath']),
    voteAverage: _asDouble(json['voteAverage']),
  );

  final int id;
  final String name;
  final int number;
  final int seasonNumber;
  final String? overview;
  final DateTime? airDate;
  final String? stillPath;
  final double voteAverage;
}

abstract class SeerrMediaDetails {
  const SeerrMediaDetails({
    required this.id,
    required this.type,
    required this.title,
    required this.overview,
    required this.genres,
    required this.cast,
    required this.crew,
    required this.productionCompanies,
    required this.relatedVideos,
    required this.voteAverage,
    this.originalTitle,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.runtimeMinutes,
    this.tagline,
    this.status,
    this.mediaInfo,
    this.homepage,
    this.originalLanguage,
    this.voteCount = 0,
    this.budget,
    this.revenue,
    this.imdbId,
    this.certifications = const {},
    this.theatricalReleaseDates = const {},
    this.videoReleaseDates = const {},
  });

  final int id;
  final SeerrMediaType type;
  final String title;
  final String? originalTitle;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final int? runtimeMinutes;
  final String? tagline;
  final String? status;
  final double voteAverage;
  final List<SeerrGenre> genres;
  final List<SeerrCastMember> cast;
  final List<SeerrCrewMember> crew;
  final List<SeerrCompany> productionCompanies;
  final List<SeerrRelatedVideo> relatedVideos;
  final SeerrMediaInfo? mediaInfo;
  final String? homepage;
  final String? originalLanguage;
  final int voteCount;
  final int? budget;
  final int? revenue;
  final String? imdbId;
  final Map<String, String> certifications;
  final Map<String, DateTime> theatricalReleaseDates;
  final Map<String, DateTime> videoReleaseDates;

  String? certificationFor(String region) =>
      certifications[region] ??
      certifications['US'] ??
      certifications.values.firstOrNull;

  DateTime? theatricalReleaseFor(String region) =>
      theatricalReleaseDates[region] ??
      releaseDate ??
      theatricalReleaseDates.values.firstOrNull;

  DateTime? videoReleaseFor(String region) =>
      videoReleaseDates[region] ?? videoReleaseDates.values.firstOrNull;
}

class SeerrMovieDetails extends SeerrMediaDetails {
  const SeerrMovieDetails({
    required super.id,
    required super.title,
    required super.overview,
    required super.genres,
    required super.cast,
    required super.crew,
    required super.productionCompanies,
    required super.relatedVideos,
    required super.voteAverage,
    super.originalTitle,
    super.posterPath,
    super.backdropPath,
    super.releaseDate,
    super.runtimeMinutes,
    super.tagline,
    super.status,
    super.mediaInfo,
    super.homepage,
    super.originalLanguage,
    super.voteCount,
    super.budget,
    super.revenue,
    super.imdbId,
    super.certifications,
    super.theatricalReleaseDates,
    super.videoReleaseDates,
  }) : super(type: SeerrMediaType.movie);

  factory SeerrMovieDetails.fromJson(Map<String, dynamic> json) {
    final releases = _decodeMovieReleases(json['releases']);
    return SeerrMovieDetails(
      id: _asInt(json['id']),
      title: _asString(json['title']) ?? '',
      originalTitle: _asString(json['originalTitle']),
      overview: _asString(json['overview']) ?? '',
      posterPath: _asString(json['posterPath']),
      backdropPath: _asString(json['backdropPath']),
      releaseDate: _asDate(_asString(json['releaseDate'])),
      runtimeMinutes: _asNullableInt(json['runtime']),
      tagline: _asString(json['tagline']),
      status: _asString(json['status']),
      voteAverage: _asDouble(json['voteAverage']),
      genres: _decodeList(json['genres'], SeerrGenre.fromJson),
      cast: _decodeCredits(json),
      crew: _decodeCrew(json),
      productionCompanies: _decodeList(
        json['productionCompanies'],
        SeerrCompany.fromJson,
      ),
      relatedVideos: _decodeList(
        json['relatedVideos'],
        SeerrRelatedVideo.fromJson,
      ),
      homepage: _asString(json['homepage']),
      originalLanguage: _asString(json['originalLanguage']),
      voteCount: _asInt(json['voteCount']),
      budget: _asNullableInt(json['budget']),
      revenue: _asNullableInt(json['revenue']),
      imdbId:
          _asString(json['imdbId']) ??
          _asString(_asMap(json['externalIds'])?['imdbId']),
      certifications: releases.certifications,
      theatricalReleaseDates: releases.theatricalDates,
      videoReleaseDates: releases.videoDates,
      mediaInfo: _decodeMediaInfo(json),
    );
  }
}

class SeerrTvDetails extends SeerrMediaDetails {
  const SeerrTvDetails({
    required super.id,
    required super.title,
    required super.overview,
    required super.genres,
    required super.cast,
    required super.crew,
    required super.productionCompanies,
    required super.relatedVideos,
    required super.voteAverage,
    required this.seasons,
    super.originalTitle,
    super.posterPath,
    super.backdropPath,
    super.releaseDate,
    super.runtimeMinutes,
    super.tagline,
    super.status,
    super.mediaInfo,
    super.homepage,
    super.originalLanguage,
    super.voteCount,
    super.imdbId,
    super.certifications,
  }) : super(type: SeerrMediaType.tv);

  factory SeerrTvDetails.fromJson(Map<String, dynamic> json) {
    final runtimes = _asList(
      json['episodeRunTime'],
    ).map(_asInt).where((v) => v > 0);
    return SeerrTvDetails(
      id: _asInt(json['id']),
      title: _asString(json['name']) ?? '',
      originalTitle: _asString(json['originalName']),
      overview: _asString(json['overview']) ?? '',
      posterPath: _asString(json['posterPath']),
      backdropPath: _asString(json['backdropPath']),
      releaseDate: _asDate(_asString(json['firstAirDate'])),
      runtimeMinutes: runtimes.isEmpty ? null : runtimes.first,
      tagline: _asString(json['tagline']),
      status: _asString(json['status']),
      voteAverage: _asDouble(json['voteAverage']),
      genres: _decodeList(json['genres'], SeerrGenre.fromJson),
      cast: _decodeCredits(json),
      crew: _decodeCrew(json),
      productionCompanies: _decodeList(
        json['productionCompanies'],
        SeerrCompany.fromJson,
      ),
      relatedVideos: _decodeList(
        json['relatedVideos'],
        SeerrRelatedVideo.fromJson,
      ),
      homepage: _asString(json['homepage']),
      originalLanguage: _asString(json['originalLanguage']),
      voteCount: _asInt(json['voteCount']),
      imdbId:
          _asString(json['imdbId']) ??
          _asString(_asMap(json['externalIds'])?['imdbId']),
      certifications: _decodeTvCertifications(json['contentRatings']),
      seasons: _decodeList(json['seasons'], SeerrSeason.fromJson),
      mediaInfo: _decodeMediaInfo(json),
    );
  }

  final List<SeerrSeason> seasons;
}

class SeerrRatings {
  const SeerrRatings({
    this.rottenTomatoesCriticsScore,
    this.rottenTomatoesAudienceScore,
    this.imdbScore,
    this.rottenTomatoesUrl,
    this.imdbUrl,
  });

  factory SeerrRatings.fromMovieJson(Map<String, dynamic> json) {
    final rottenTomatoes = _asMap(json['rt']) ?? const <String, dynamic>{};
    final imdb = _asMap(json['imdb']) ?? const <String, dynamic>{};
    return SeerrRatings(
      rottenTomatoesCriticsScore: _asNullableDouble(
        rottenTomatoes['criticsScore'],
      ),
      rottenTomatoesAudienceScore: _asNullableDouble(
        rottenTomatoes['audienceScore'],
      ),
      imdbScore: _asNullableDouble(imdb['criticsScore']),
      rottenTomatoesUrl: _asString(rottenTomatoes['url']),
      imdbUrl: _asString(imdb['url']),
    );
  }

  factory SeerrRatings.fromTvJson(Map<String, dynamic> json) {
    return SeerrRatings(
      rottenTomatoesCriticsScore: _asNullableDouble(json['criticsScore']),
      rottenTomatoesAudienceScore: _asNullableDouble(json['audienceScore']),
      rottenTomatoesUrl: _asString(json['url']),
    );
  }

  final double? rottenTomatoesCriticsScore;
  final double? rottenTomatoesAudienceScore;
  final double? imdbScore;
  final String? rottenTomatoesUrl;
  final String? imdbUrl;

  bool get isEmpty =>
      rottenTomatoesCriticsScore == null &&
      rottenTomatoesAudienceScore == null &&
      imdbScore == null;
}

class SeerrMediaRequest {
  const SeerrMediaRequest({
    required this.id,
    required this.status,
    this.media,
    this.createdAt,
    this.type = SeerrMediaType.unknown,
    this.is4k = false,
    this.seasons = const [],
  });

  factory SeerrMediaRequest.fromJson(Map<String, dynamic> json) {
    return SeerrMediaRequest(
      id: _asInt(json['id']),
      status: SeerrRequestStatus.fromJson(json['status']),
      media: _decodeMediaInfoValue(json['media']),
      createdAt: _asDate(_asString(json['createdAt'])),
      type: SeerrMediaType.fromJson(json['type']),
      is4k: json['is4k'] == true,
      seasons: _decodeList(json['seasons'], SeerrSeasonRequest.fromJson),
    );
  }

  final int id;
  final SeerrRequestStatus status;
  final SeerrMediaInfo? media;
  final DateTime? createdAt;
  final SeerrMediaType type;
  final bool is4k;
  final List<SeerrSeasonRequest> seasons;
}

class SeerrSeasonRequest {
  const SeerrSeasonRequest({required this.number, required this.status});

  factory SeerrSeasonRequest.fromJson(Map<String, dynamic> json) =>
      SeerrSeasonRequest(
        number: _asInt(json['seasonNumber']),
        status: SeerrRequestStatus.fromJson(json['status']),
      );

  final int number;
  final SeerrRequestStatus status;
}

class SeerrUserRequests {
  const SeerrUserRequests({required this.results, required this.totalResults});

  factory SeerrUserRequests.fromJson(Map<String, dynamic> json) {
    final pageInfo = _asMap(json['pageInfo']);
    return SeerrUserRequests(
      results: _decodeList(json['results'], SeerrMediaRequest.fromJson),
      totalResults: _asInt(pageInfo?['results']),
    );
  }

  final List<SeerrMediaRequest> results;
  final int totalResults;
}

SeerrMediaInfo? _decodeMediaInfo(Map<String, dynamic> json) {
  return _decodeMediaInfoValue(json['mediaInfo']);
}

SeerrMediaInfo? _decodeMediaInfoValue(Object? value) {
  final info = _asMap(value);
  return info == null ? null : SeerrMediaInfo.fromJson(info);
}

List<SeerrCastMember> _decodeCredits(Map<String, dynamic> json) {
  final credits = _asMap(json['credits']);
  return _decodeList(credits?['cast'], SeerrCastMember.fromJson);
}

List<SeerrCrewMember> _decodeCrew(Map<String, dynamic> json) {
  final credits = _asMap(json['credits']);
  return _decodeList(credits?['crew'], SeerrCrewMember.fromJson);
}

({
  Map<String, String> certifications,
  Map<String, DateTime> theatricalDates,
  Map<String, DateTime> videoDates,
})
_decodeMovieReleases(Object? value) {
  final certifications = <String, String>{};
  final theatricalDates = <String, DateTime>{};
  final videoDates = <String, DateTime>{};
  final results = _asList(_asMap(value)?['results']);
  for (final resultValue in results) {
    final result = _asMap(resultValue);
    final region = _asString(result?['iso_3166_1']);
    if (region == null) continue;
    final events = _asList(
      result?['release_dates'],
    ).map(_asMap).whereType<Map<String, dynamic>>();
    for (final event in events) {
      final type = _asInt(event['type']);
      final date = _asDate(_asString(event['release_date']));
      final certification = _asString(event['certification']);
      if (certification != null &&
          (!certifications.containsKey(region) || type == 3)) {
        certifications[region] = certification;
      }
      if (date != null && type == 3) {
        final current = theatricalDates[region];
        if (current == null || date.isBefore(current)) {
          theatricalDates[region] = date;
        }
      }
      if (date != null && (type == 4 || type == 5)) {
        final current = videoDates[region];
        if (current == null || date.isBefore(current)) {
          videoDates[region] = date;
        }
      }
    }
  }
  return (
    certifications: Map.unmodifiable(certifications),
    theatricalDates: Map.unmodifiable(theatricalDates),
    videoDates: Map.unmodifiable(videoDates),
  );
}

Map<String, String> _decodeTvCertifications(Object? value) {
  final certifications = <String, String>{};
  for (final resultValue in _asList(_asMap(value)?['results'])) {
    final result = _asMap(resultValue);
    final region = _asString(result?['iso_3166_1']);
    final rating = _asString(result?['rating']);
    if (region != null && rating != null) certifications[region] = rating;
  }
  return Map.unmodifiable(certifications);
}

List<T> _decodeList<T>(Object? value, T Function(Map<String, dynamic>) decode) {
  return _asList(value)
      .map(_asMap)
      .whereType<Map<String, dynamic>>()
      .map(decode)
      .toList(growable: false);
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return null;
}

List<Object?> _asList(Object? value) {
  return value is List ? value.cast<Object?>() : const [];
}

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _asDate(String? value) =>
    value == null ? null : DateTime.tryParse(value);
