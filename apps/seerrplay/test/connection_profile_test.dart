import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

void main() {
  test('maps every Seerr media server type', () {
    expect(MediaServerType.fromSeerrValue(1), MediaServerType.plex);
    expect(MediaServerType.fromSeerrValue(2), MediaServerType.jellyfin);
    expect(MediaServerType.fromSeerrValue(3), MediaServerType.emby);
    expect(MediaServerType.fromSeerrValue(4), isNull);
  });

  group('ConnectionProfile.parseServerUrl', () {
    test('normalizes the trailing slash', () {
      expect(
        ConnectionProfile.parseServerUrl('https://media.example.test///'),
        Uri.parse('https://media.example.test'),
      );
    });

    test('preserves a server subpath', () {
      expect(
        ConnectionProfile.parseServerUrl('https://example.test/jellyfin/'),
        Uri.parse('https://example.test/jellyfin'),
      );
    });

    test('rejects a URL without a scheme', () {
      expect(
        () => ConnectionProfile.parseServerUrl('media.example.test'),
        throwsFormatException,
      );
    });
  });

  group('ConnectionProfile serialization', () {
    test('persists the selected avatar', () {
      final profile = ConnectionProfile(
        id: 'home',
        name: 'Home',
        seerrBaseUrl: Uri.parse('https://seerr.example.test'),
        mediaServerBaseUrl: Uri.parse('https://media.example.test'),
        mediaServerType: MediaServerType.jellyfin,
        avatarIndex: 5,
      );

      final decoded = ConnectionProfile.decodeList(
        ConnectionProfile.encodeList([profile]),
      ).single;

      expect(decoded.avatarIndex, 5);
      expect(decoded.mediaServerType, MediaServerType.jellyfin);
    });

    test('assigns a stable avatar to legacy profiles', () {
      final profile = ConnectionProfile.fromJson({
        'id': 'legacy',
        'name': 'Legacy',
        'seerrBaseUrl': 'https://seerr.example.test',
        'mediaServerBaseUrl': 'https://media.example.test',
      });

      expect(profile.avatarIndex, inInclusiveRange(0, 7));
    });
  });
}
