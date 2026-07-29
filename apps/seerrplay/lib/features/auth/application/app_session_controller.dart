import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/features/profiles/application/profiles_controller.dart';
import 'package:seerrplay/features/profiles/data/credential_store.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => CredentialStore(),
);

final appSessionControllerProvider =
    AsyncNotifierProvider<AppSessionController, AppSessionState>(
      AppSessionController.new,
    );

class AppSessionState {
  const AppSessionState({required this.profile, required this.credentials});

  final ConnectionProfile? profile;
  final ProfileCredentials? credentials;

  bool get isAuthenticated => profile != null && credentials != null;
}

class AppSessionController extends AsyncNotifier<AppSessionState> {
  CredentialStore get _credentials => ref.read(credentialStoreProvider);

  @override
  Future<AppSessionState> build() async {
    final profiles = await ref.watch(profilesControllerProvider.future);
    final profile = profiles.activeProfile;
    if (profile == null) {
      return const AppSessionState(profile: null, credentials: null);
    }
    return AppSessionState(
      profile: profile,
      credentials: await _credentials.readCredentials(profile.id),
    );
  }

  Future<void> saveCredentials(ProfileCredentials credentials) async {
    final profile = state.requireValue.profile;
    if (profile == null) return;
    await _credentials.writeCredentials(profile.id, credentials);
    state = AsyncData(
      AppSessionState(profile: profile, credentials: credentials),
    );
  }

  Future<void> disconnect() async {
    final profile = state.requireValue.profile;
    if (profile == null) return;
    await _credentials.deleteProfile(profile.id);
    state = AsyncData(AppSessionState(profile: profile, credentials: null));
  }
}
