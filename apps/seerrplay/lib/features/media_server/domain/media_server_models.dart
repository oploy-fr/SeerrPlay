class MediaServerSession {
  const MediaServerSession({
    required this.accessToken,
    required this.user,
    this.serverId,
  });

  final String accessToken;
  final MediaServerUser user;
  final String? serverId;

  factory MediaServerSession.fromJson(Map<String, dynamic> json) {
    final userJson = _asMap(json['User']);
    return MediaServerSession(
      accessToken: _asString(json['AccessToken']) ?? '',
      user: MediaServerUser.fromJson(userJson),
      serverId:
          _asString(json['ServerId']) ??
          _asString(_asMap(json['SessionInfo'])['ServerId']),
    );
  }
}

class MediaServerUser {
  const MediaServerUser({
    required this.id,
    required this.name,
    this.serverId,
    this.primaryImageTag,
  });

  final String id;
  final String name;
  final String? serverId;
  final String? primaryImageTag;

  factory MediaServerUser.fromJson(Map<String, dynamic> json) {
    return MediaServerUser(
      id: _asString(json['Id']) ?? '',
      name: _asString(json['Name']) ?? '',
      serverId: _asString(json['ServerId']),
      primaryImageTag: _asString(json['PrimaryImageTag']),
    );
  }
}

class MediaServerItemsPage {
  const MediaServerItemsPage({
    required this.items,
    required this.totalRecordCount,
    required this.startIndex,
  });

  final List<MediaServerItem> items;
  final int totalRecordCount;
  final int startIndex;

  factory MediaServerItemsPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['Items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    MediaServerItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false)
        : const <MediaServerItem>[];

    return MediaServerItemsPage(
      items: items,
      totalRecordCount: _asInt(json['TotalRecordCount']) ?? items.length,
      startIndex: _asInt(json['StartIndex']) ?? 0,
    );
  }
}

class MediaServerItem {
  const MediaServerItem({
    required this.id,
    required this.name,
    required this.type,
    this.overview,
    this.runTimeTicks,
    this.productionYear,
    this.premiereDate,
    this.communityRating,
    this.officialRating,
    this.seriesName,
    this.seriesId,
    this.parentIndexNumber,
    this.indexNumber,
    this.providerIds = const {},
    this.imageTags = const {},
    this.backdropImageTags = const [],
    this.primaryImagePath,
    this.backdropImagePath,
    this.userData,
  });

  final String id;
  final String name;
  final String type;
  final String? overview;
  final int? runTimeTicks;
  final int? productionYear;
  final DateTime? premiereDate;
  final double? communityRating;
  final String? officialRating;
  final String? seriesName;
  final String? seriesId;
  final int? parentIndexNumber;
  final int? indexNumber;
  final Map<String, String> providerIds;
  final Map<String, String> imageTags;
  final List<String> backdropImageTags;
  final String? primaryImagePath;
  final String? backdropImagePath;
  final MediaServerUserData? userData;

  String? get primaryImageTag => imageTags['Primary'];

  factory MediaServerItem.fromJson(Map<String, dynamic> json) {
    final rawBackdropTags = json['BackdropImageTags'];
    return MediaServerItem(
      id: _asString(json['Id']) ?? '',
      name: _asString(json['Name']) ?? '',
      type: _asString(json['Type']) ?? '',
      overview: _asString(json['Overview']),
      runTimeTicks: _asInt(json['RunTimeTicks']),
      productionYear: _asInt(json['ProductionYear']),
      premiereDate: _asDateTime(json['PremiereDate']),
      communityRating: _asDouble(json['CommunityRating']),
      officialRating: _asString(json['OfficialRating']),
      seriesName: _asString(json['SeriesName']),
      seriesId: _asString(json['SeriesId']),
      parentIndexNumber: _asInt(json['ParentIndexNumber']),
      indexNumber: _asInt(json['IndexNumber']),
      providerIds: _asStringMap(json['ProviderIds']),
      imageTags: _asStringMap(json['ImageTags']),
      backdropImageTags: rawBackdropTags is List
          ? rawBackdropTags.whereType<String>().toList(growable: false)
          : const [],
      primaryImagePath: _asString(json['PrimaryImagePath']),
      backdropImagePath: _asString(json['BackdropImagePath']),
      userData: json['UserData'] is Map
          ? MediaServerUserData.fromJson(_asMap(json['UserData']))
          : null,
    );
  }
}

class MediaServerUserData {
  const MediaServerUserData({
    this.playbackPositionTicks = 0,
    this.playCount = 0,
    this.isFavorite = false,
    this.played = false,
    this.lastPlayedDate,
    this.key,
  });

  final int playbackPositionTicks;
  final int playCount;
  final bool isFavorite;
  final bool played;
  final DateTime? lastPlayedDate;
  final String? key;

  factory MediaServerUserData.fromJson(Map<String, dynamic> json) {
    return MediaServerUserData(
      playbackPositionTicks: _asInt(json['PlaybackPositionTicks']) ?? 0,
      playCount: _asInt(json['PlayCount']) ?? 0,
      isFavorite: _asBool(json['IsFavorite']) ?? false,
      played: _asBool(json['Played']) ?? false,
      lastPlayedDate: _asDateTime(json['LastPlayedDate']),
      key: _asString(json['Key']),
    );
  }
}

class MediaServerPlaybackInfo {
  const MediaServerPlaybackInfo({
    required this.mediaSources,
    this.playSessionId,
  });

  factory MediaServerPlaybackInfo.fromJson(Map<String, dynamic> json) {
    final sources = json['MediaSources'];
    return MediaServerPlaybackInfo(
      playSessionId: _asString(json['PlaySessionId']),
      mediaSources: sources is List
          ? sources
                .whereType<Map>()
                .map(
                  (source) => MediaServerSource.fromJson(
                    Map<String, dynamic>.from(source),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final List<MediaServerSource> mediaSources;
  final String? playSessionId;
}

class MediaServerSource {
  const MediaServerSource({
    required this.id,
    this.name,
    this.container,
    this.transcodingUrl,
    this.runTimeTicks,
    this.sizeBytes,
    this.bitrate,
    this.supportsDirectPlay = false,
    this.supportsDirectStream = false,
    this.mediaStreams = const [],
    this.defaultAudioStreamIndex,
    this.defaultSubtitleStreamIndex,
    this.directStreamPath,
    this.metadataPath,
  });

  factory MediaServerSource.fromJson(Map<String, dynamic> json) =>
      MediaServerSource(
        id: _asString(json['Id']) ?? '',
        name: _asString(json['Name']),
        container: _asString(json['Container']),
        transcodingUrl: _asString(json['TranscodingUrl']),
        runTimeTicks: _asInt(json['RunTimeTicks']),
        sizeBytes: _asInt(json['Size']),
        bitrate: _asInt(json['Bitrate']),
        supportsDirectPlay: _asBool(json['SupportsDirectPlay']) ?? false,
        supportsDirectStream: _asBool(json['SupportsDirectStream']) ?? false,
        mediaStreams: json['MediaStreams'] is List
            ? (json['MediaStreams'] as List)
                  .whereType<Map>()
                  .map(
                    (stream) =>
                        MediaStream.fromJson(Map<String, dynamic>.from(stream)),
                  )
                  .toList(growable: false)
            : const [],
        defaultAudioStreamIndex: _asInt(json['DefaultAudioStreamIndex']),
        defaultSubtitleStreamIndex: _asInt(json['DefaultSubtitleStreamIndex']),
        directStreamPath: _asString(json['DirectStreamPath']),
        metadataPath: _asString(json['MetadataPath']),
      );

  final String id;
  final String? name;
  final String? container;
  final String? transcodingUrl;
  final int? runTimeTicks;
  final int? sizeBytes;
  final int? bitrate;
  final bool supportsDirectPlay;
  final bool supportsDirectStream;
  final List<MediaStream> mediaStreams;
  final int? defaultAudioStreamIndex;
  final int? defaultSubtitleStreamIndex;
  final String? directStreamPath;
  final String? metadataPath;

  List<MediaStream> get audioStreams => mediaStreams
      .where((stream) => stream.type == MediaStreamType.audio)
      .toList(growable: false);

  List<MediaStream> get subtitleStreams => mediaStreams
      .where((stream) => stream.type == MediaStreamType.subtitle)
      .toList(growable: false);

  String get playMethod => transcodingUrl?.isNotEmpty == true
      ? 'Transcode'
      : supportsDirectPlay
      ? 'DirectPlay'
      : 'DirectStream';
}

enum MediaStreamType { audio, subtitle, video, unknown }

class MediaStream {
  const MediaStream({
    required this.index,
    required this.type,
    this.displayTitle,
    this.title,
    this.language,
    this.codec,
    this.isDefault = false,
    this.isForced = false,
    this.isExternal = false,
    this.channels,
    this.width,
    this.height,
    this.bitRate,
    this.deliveryUrl,
  });

  factory MediaStream.fromJson(Map<String, dynamic> json) {
    final rawType = _asString(json['Type'])?.toLowerCase();
    return MediaStream(
      index: _asInt(json['Index']) ?? -1,
      type: switch (rawType) {
        'audio' => MediaStreamType.audio,
        'subtitle' => MediaStreamType.subtitle,
        'video' => MediaStreamType.video,
        _ => MediaStreamType.unknown,
      },
      displayTitle: _asString(json['DisplayTitle']),
      title: _asString(json['Title']),
      language: _asString(json['Language']),
      codec: _asString(json['Codec']),
      isDefault: _asBool(json['IsDefault']) ?? false,
      isForced: _asBool(json['IsForced']) ?? false,
      isExternal: _asBool(json['IsExternal']) ?? false,
      channels: _asInt(json['Channels']),
      width: _asInt(json['Width']),
      height: _asInt(json['Height']),
      bitRate: _asInt(json['BitRate']),
      deliveryUrl: _asString(json['DeliveryUrl']),
    );
  }

  final int index;
  final MediaStreamType type;
  final String? displayTitle;
  final String? title;
  final String? language;
  final String? codec;
  final bool isDefault;
  final bool isForced;
  final bool isExternal;
  final int? channels;
  final int? width;
  final int? height;
  final int? bitRate;
  final String? deliveryUrl;

  String get label {
    final explicitTitle = displayTitle?.trim();
    if (explicitTitle != null && explicitTitle.isNotEmpty) return explicitTitle;
    final values = <String>[
      if (language?.isNotEmpty == true) language!.toUpperCase(),
      if (title?.isNotEmpty == true) title!,
      if (codec?.isNotEmpty == true) codec!.toUpperCase(),
      if (channels != null) '${channels!} channels',
    ];
    return values.isEmpty ? 'Piste ${index + 1}' : values.join(' · ');
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

Map<String, String> _asStringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

String? _asString(Object? value) => value is String ? value : null;

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

bool? _asBool(Object? value) => value is bool ? value : null;

DateTime? _asDateTime(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
