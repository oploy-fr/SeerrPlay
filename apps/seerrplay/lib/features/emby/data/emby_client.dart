import 'package:seerrplay/features/jellyfin/data/jellyfin_client.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

class EmbyClient extends JellyfinClient {
  EmbyClient({required super.baseUrl, required super.deviceId, super.dio})
    : super(
        serverType: MediaServerType.emby,
        clientName: 'SeerrPlay',
        deviceName: 'SeerrPlay',
      );
}
