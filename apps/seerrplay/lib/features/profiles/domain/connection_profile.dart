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
  });

  final String id;
  final String name;
  final Uri seerrBaseUrl;
  final Uri mediaServerBaseUrl;
  final MediaServerType mediaServerType;
  final int avatarIndex;

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
  };

  factory ConnectionProfile.fromJson(Map<String, Object?> json) {
    return ConnectionProfile(
      id: json['id']! as String,
      name: json['name']! as String,
      seerrBaseUrl: Uri.parse(json['seerrBaseUrl']! as String),
      mediaServerBaseUrl: Uri.parse(
        (json['mediaServerBaseUrl'] ?? json['mediaServerBaseUrl'])! as String,
      ),
      mediaServerType: MediaServerType.fromJson(json['mediaServerType']),
      avatarIndex:
          (json['avatarIndex'] as num?)?.toInt() ??
          (json['id']! as String).codeUnits.fold<int>(
                0,
                (total, value) => total + value,
              ) %
              8,
    );
  }

  static String encodeList(List<ConnectionProfile> profiles) {
    return jsonEncode(profiles.map((profile) => profile.toJson()).toList());
  }

  static List<ConnectionProfile> decodeList(String? value) {
    if (value == null || value.isEmpty) return const [];
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .map(
          (item) => ConnectionProfile.fromJson(
            Map<String, Object?>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList(growable: false);
  }
}
