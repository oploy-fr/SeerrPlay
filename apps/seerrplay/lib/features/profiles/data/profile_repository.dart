import 'package:shared_preferences/shared_preferences.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

abstract interface class ProfileRepository {
  Future<List<ConnectionProfile>> readProfiles();
  Future<String?> readActiveProfileId();
  Future<void> saveProfiles(List<ConnectionProfile> profiles);
  Future<void> saveActiveProfileId(String? profileId);
}

class LocalProfileRepository implements ProfileRepository {
  static const _profilesKey = 'connection_profiles_v1';
  static const _activeProfileKey = 'active_connection_profile_v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<List<ConnectionProfile>> readProfiles() async {
    final preferences = await _preferences;
    return ConnectionProfile.decodeList(preferences.getString(_profilesKey));
  }

  @override
  Future<String?> readActiveProfileId() async {
    final preferences = await _preferences;
    return preferences.getString(_activeProfileKey);
  }

  @override
  Future<void> saveProfiles(List<ConnectionProfile> profiles) async {
    final preferences = await _preferences;
    await preferences.setString(
      _profilesKey,
      ConnectionProfile.encodeList(profiles),
    );
  }

  @override
  Future<void> saveActiveProfileId(String? profileId) async {
    final preferences = await _preferences;
    if (profileId == null) {
      await preferences.remove(_activeProfileKey);
      return;
    }
    await preferences.setString(_activeProfileKey, profileId);
  }
}
