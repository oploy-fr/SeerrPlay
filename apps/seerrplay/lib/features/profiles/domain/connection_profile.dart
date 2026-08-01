import 'dart:convert';

enum MediaServerType {
  plex(1, 'Plex'),
  jellyfin(2, 'Jellyfin'),
  emby(3, 'Emby');

  const MediaServerType(this.seerrValue, this.displayName);

  final int seerrValue;
  final String displayName;

  static MediaServerType? fromSeerrValue(int? value) {
    for (final type in values) {
      if (type.seerrValue == value) return type;
    }
    return null;
  }

  static MediaServerType fromJson(Object? value) {
    final name = value?.toString();
    return values.firstWhere(
      (type) => type.name == name,
      orElse: () => MediaServerType.jellyfin,
    );
  }
}

class ConnectionProfile {
  const ConnectionProfile({
    required this.id,
    required this.name,
    required this.seerrBaseUrl,
    required this.mediaServerBaseUrl,
    required this.mediaServerType,
    this.avatarIndex = 0,
    this.childMode = false,
    this.maximumContentAge = 12,
  });

  final String id;
  final String name;
  final Uri seerrBaseUrl;
  final Uri mediaServerBaseUrl;
  final MediaServerType mediaServerType;
  final int avatarIndex;
  final bool childMode;
  final int maximumContentAge;

  ConnectionProfile copyWith({bool? childMode, int? maximumContentAge}) {
    return ConnectionProfile(
      id: id,
      name: name,
      seerrBaseUrl: seerrBaseUrl,
      mediaServerBaseUrl: mediaServerBaseUrl,
      mediaServerType: mediaServerType,
      avatarIndex: avatarIndex,
      childMode: childMode ?? this.childMode,
      maximumContentAge: maximumContentAge ?? this.maximumContentAge,
    );
  }

  static Uri parseServerUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid server address');
    }

    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'seerrBaseUrl': seerrBaseUrl.toString(),
    'mediaServerBaseUrl': mediaServerBaseUrl.toString(),
    'mediaServerType': mediaServerType.name,
    'avatarIndex': avatarIndex,
    'childMode': childMode,
    'maximumContentAge': maximumContentAge,
  };

  factory ConnectionProfile.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final seerrUrl = json['seerrBaseUrl'];
    final mediaServerUrl =
        json['mediaServerBaseUrl'] ?? json['jellyfinBaseUrl'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        seerrUrl is! String ||
        mediaServerUrl is! String) {
      throw const FormatException('Invalid connection profile');
    }
    final storedAvatarIndex = json['avatarIndex'];
    final storedChildMode = json['childMode'];
    final storedMaximumAge = json['maximumContentAge'];
    return ConnectionProfile(
      id: id,
      name: name,
      seerrBaseUrl: parseServerUrl(seerrUrl),
      mediaServerBaseUrl: parseServerUrl(mediaServerUrl),
      mediaServerType: MediaServerType.fromJson(json['mediaServerType']),
      avatarIndex:
          (storedAvatarIndex is num ? storedAvatarIndex.toInt() : null) ??
          id.codeUnits.fold<int>(0, (total, value) => total + value) % 8,
      childMode: storedChildMode is bool ? storedChildMode : false,
      maximumContentAge:
          (storedMaximumAge is num ? storedMaximumAge.toInt() : 12).clamp(
            0,
            18,
          ),
    );
  }

  static String encodeList(List<ConnectionProfile> profiles) {
    return jsonEncode(profiles.map((profile) => profile.toJson()).toList());
  }

  static List<ConnectionProfile> decodeList(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return const [];
      final profiles = <ConnectionProfile>[];
      for (final item in decoded.whereType<Map>()) {
        try {
          profiles.add(
            ConnectionProfile.fromJson(Map<String, Object?>.from(item)),
          );
        } on FormatException {
          // A single damaged legacy profile must not prevent app startup or
          // access to the other valid profiles stored beside it.
        }
      }
      return profiles;
    } on FormatException {
      return const [];
    }
  }
}
