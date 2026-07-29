import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStore {
  CredentialStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _key(String profileId, String name) =>
      'profile.$profileId.$name';

  Future<void> writeSeerrSession(String profileId, String sessionCookie) {
    return _storage.write(
      key: _key(profileId, 'seerr.session'),
      value: sessionCookie,
    );
  }

  Future<void> writeMediaServerToken(String profileId, String accessToken) {
    return _storage.write(
      key: _key(profileId, 'mediaServer.token'),
      value: accessToken,
    );
  }

  Future<String?> readSeerrSession(String profileId) {
    return _storage.read(key: _key(profileId, 'seerr.session'));
  }

  Future<String?> readMediaServerToken(String profileId) {
    return _storage.read(key: _key(profileId, 'mediaServer.token'));
  }

  Future<void> writeCredentials(
    String profileId,
    ProfileCredentials credentials,
  ) async {
    await Future.wait([
      _storage.write(
        key: _key(profileId, 'seerr.session'),
        value: credentials.seerrSessionCookie,
      ),
      _storage.write(
        key: _key(profileId, 'seerr.userId'),
        value: credentials.seerrUserId.toString(),
      ),
      _storage.write(
        key: _key(profileId, 'mediaServer.token'),
        value: credentials.mediaServerAccessToken,
      ),
      _storage.write(
        key: _key(profileId, 'mediaServer.userId'),
        value: credentials.mediaServerUserId,
      ),
      _storage.write(
        key: _key(profileId, 'mediaServer.serverId'),
        value: credentials.mediaServerServerId,
      ),
    ]);
  }

  Future<ProfileCredentials?> readCredentials(String profileId) async {
    final values = await Future.wait([
      _storage.read(key: _key(profileId, 'seerr.session')),
      _storage.read(key: _key(profileId, 'seerr.userId')),
      _storage.read(key: _key(profileId, 'mediaServer.token')),
      _storage.read(key: _key(profileId, 'mediaServer.userId')),
      _storage.read(key: _key(profileId, 'mediaServer.serverId')),
    ]);
    final seerrUserId = int.tryParse(values[1] ?? '');
    if (values[0] == null ||
        seerrUserId == null ||
        values[2] == null ||
        values[3] == null ||
        values[4] == null) {
      return null;
    }
    return ProfileCredentials(
      seerrSessionCookie: values[0]!,
      seerrUserId: seerrUserId,
      mediaServerAccessToken: values[2]!,
      mediaServerUserId: values[3]!,
      mediaServerServerId: values[4]!,
    );
  }

  Future<void> deleteProfile(String profileId) async {
    await Future.wait([
      _storage.delete(key: _key(profileId, 'seerr.session')),
      _storage.delete(key: _key(profileId, 'seerr.userId')),
      _storage.delete(key: _key(profileId, 'mediaServer.token')),
      _storage.delete(key: _key(profileId, 'mediaServer.userId')),
      _storage.delete(key: _key(profileId, 'mediaServer.serverId')),
    ]);
  }
}

class ProfileCredentials {
  const ProfileCredentials({
    required this.seerrSessionCookie,
    required this.seerrUserId,
    required this.mediaServerAccessToken,
    required this.mediaServerUserId,
    required this.mediaServerServerId,
  });

  final String seerrSessionCookie;
  final int seerrUserId;
  final String mediaServerAccessToken;
  final String mediaServerUserId;
  final String mediaServerServerId;
}
