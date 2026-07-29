import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/core/widgets/seerr_brand_logo.dart';
import 'package:seerrplay/features/profiles/application/profiles_controller.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:seerrplay/features/profiles/presentation/profile_avatar.dart';
import 'package:seerrplay/features/profiles/presentation/profile_setup_screen.dart';

class ProfileSelectionScreen extends ConsumerWidget {
  const ProfileSelectionScreen({
    required this.onProfileSelected,
    super.key,
    this.onProfileCreated,
    this.showBackButton = false,
  });

  final ValueChanged<String> onProfileSelected;
  final VoidCallback? onProfileCreated;
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        title: const SeerrBrandLogo(compact: true),
        centerTitle: true,
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr(
                'Unable to load profiles.\n{error}',
                arguments: {'error': error},
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (state) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 56 : 24,
                wide ? 72 : 42,
                wide ? 56 : 24,
                48,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    children: [
                      Text(
                        context.tr("Who's watching?"),
                        textAlign: TextAlign.center,
                        style:
                            (wide
                                    ? Theme.of(context).textTheme.displaySmall
                                    : Theme.of(
                                        context,
                                      ).textTheme.headlineMedium)
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('Choose a profile to continue.'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white60),
                      ),
                      SizedBox(height: wide ? 52 : 36),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: wide ? 30 : 20,
                        runSpacing: wide ? 34 : 26,
                        children: [
                          for (final profile in state.profiles)
                            _ProfileTile(
                              profile: profile,
                              onTap: () async {
                                await ref
                                    .read(profilesControllerProvider.notifier)
                                    .selectProfile(profile.id);
                                onProfileSelected(profile.id);
                              },
                            ),
                          _AddProfileTile(
                            onTap: () => _createProfile(context, ref),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createProfile(BuildContext context, WidgetRef ref) async {
    final profileIdsBefore = ref
        .read(profilesControllerProvider)
        .value
        ?.profiles
        .map((profile) => profile.id)
        .toSet();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => ProfileSetupScreen(
          onCompleted: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
    if (!context.mounted) return;
    final activeProfileId = ref
        .read(profilesControllerProvider)
        .value
        ?.activeProfileId;
    if (activeProfileId != null &&
        profileIdsBefore?.contains(activeProfileId) != true) {
      onProfileCreated?.call();
      onProfileSelected(activeProfileId);
    }
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile, required this.onTap});

  final ConnectionProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: profile.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 126,
          child: Column(
            children: [
              ProfileAvatar(avatarIndex: profile.avatarIndex, size: 118),
              const SizedBox(height: 12),
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddProfileTile extends StatelessWidget {
  const _AddProfileTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SizedBox(
        width: 126,
        child: Column(
          children: [
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 48,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('Add profile'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
