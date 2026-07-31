import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/features/profiles/data/profile_repository.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:uuid/uuid.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => LocalProfileRepository(),
);

final profilesControllerProvider =
    AsyncNotifierProvider<ProfilesController, ProfilesState>(
      ProfilesController.new,
    );

class ProfilesState {
  const ProfilesState({required this.profiles, required this.activeProfileId});

  final List<ConnectionProfile> profiles;
  final String? activeProfileId;

  ConnectionProfile? get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.firstOrNull;
  }
}

class ProfilesController extends AsyncNotifier<ProfilesState> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  Future<ProfilesState> build() async {
    final profiles = await _repository.readProfiles();
    final storedActiveId = await _repository.readActiveProfileId();
    final activeId = profiles.any((profile) => profile.id == storedActiveId)
        ? storedActiveId
        : profiles.firstOrNull?.id;
    return ProfilesState(profiles: profiles, activeProfileId: activeId);
  }

  Future<ConnectionProfile> addProfile({
    String? id,
    required String name,
    required String seerrUrl,
    required String mediaServerUrl,
    required MediaServerType mediaServerType,
    int avatarIndex = 0,
  }) async {
    final current = state.requireValue;
    final profile = ConnectionProfile(
      id: id ?? const Uuid().v4(),
      name: name.trim(),
      seerrBaseUrl: ConnectionProfile.parseServerUrl(seerrUrl),
      mediaServerBaseUrl: ConnectionProfile.parseServerUrl(mediaServerUrl),
      mediaServerType: mediaServerType,
      avatarIndex: avatarIndex,
    );
    final profiles = [...current.profiles, profile];
    await _repository.saveProfiles(profiles);
    await _repository.saveActiveProfileId(profile.id);
    state = AsyncData(
      ProfilesState(profiles: profiles, activeProfileId: profile.id),
    );
    return profile;
  }

  Future<void> selectProfile(String profileId) async {
    final current = state.requireValue;
    if (!current.profiles.any((profile) => profile.id == profileId)) return;
    await _repository.saveActiveProfileId(profileId);
    state = AsyncData(
      ProfilesState(profiles: current.profiles, activeProfileId: profileId),
    );
  }

  Future<void> updateContentRestrictions({
    required String profileId,
    required bool childMode,
    required int maximumContentAge,
  }) async {
    final current = state.requireValue;
    final profiles = [
      for (final profile in current.profiles)
        if (profile.id == profileId)
          profile.copyWith(
            childMode: childMode,
            maximumContentAge: maximumContentAge,
          )
        else
          profile,
    ];
    await _repository.saveProfiles(profiles);
    state = AsyncData(
      ProfilesState(
        profiles: profiles,
        activeProfileId: current.activeProfileId,
      ),
    );
  }

  Future<void> deleteProfile(String profileId) async {
    final current = state.requireValue;
    final profiles = current.profiles
        .where((profile) => profile.id != profileId)
        .toList(growable: false);
    final activeProfileId = current.activeProfileId == profileId
        ? profiles.firstOrNull?.id
        : current.activeProfileId;
    await _repository.saveProfiles(profiles);
    await _repository.saveActiveProfileId(activeProfileId);
    state = AsyncData(
      ProfilesState(profiles: profiles, activeProfileId: activeProfileId),
    );
  }
}
