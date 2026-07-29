import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/emby/data/emby_client.dart';
import 'package:seerrplay/features/jellyfin/data/jellyfin_client.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/plex/data/plex_client.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:seerrplay/features/seerr/data/seerr_client.dart';

final seerrClientProvider = Provider<SeerrClient>((ref) {
  final session = ref.watch(appSessionControllerProvider).requireValue;
  final profile = session.profile!;
  final credentials = session.credentials!;
  return SeerrClient(
    baseUrl: profile.seerrBaseUrl.toString(),
    sessionCookie: credentials.seerrSessionCookie,
  );
});

final mediaServerClientProvider = Provider<MediaServerClient>((ref) {
  final session = ref.watch(appSessionControllerProvider).requireValue;
  final profile = session.profile!;
  final credentials = session.credentials!;
  if (profile.mediaServerType == MediaServerType.plex) {
    return PlexClient(
      baseUrl: profile.mediaServerBaseUrl,
      deviceId: profile.id,
      accessToken: credentials.mediaServerAccessToken,
      machineIdentifier: credentials.mediaServerServerId,
    );
  }
  final JellyfinClient client = profile.mediaServerType == MediaServerType.emby
      ? EmbyClient(baseUrl: profile.mediaServerBaseUrl, deviceId: profile.id)
      : JellyfinClient(
          baseUrl: profile.mediaServerBaseUrl,
          deviceId: profile.id,
        );
  client.restoreSession(
    MediaServerSession(
      accessToken: credentials.mediaServerAccessToken,
      user: MediaServerUser(id: credentials.mediaServerUserId, name: ''),
      serverId: credentials.mediaServerServerId,
    ),
  );
  return client;
});
