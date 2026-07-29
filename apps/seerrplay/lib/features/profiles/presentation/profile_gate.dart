import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/features/home/presentation/home_screen.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/presentation/connection_screen.dart';
import 'package:seerrplay/features/profiles/presentation/profile_selection_screen.dart';

class ProfileGate extends ConsumerWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionControllerProvider);
    return session.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr(
                'Unable to load profiles.\n{error}',
                arguments: {'error': error},
              ),
            ),
          ),
        ),
      ),
      data: (value) {
        final profile = value.profile;
        if (profile == null) {
          return ProfileSelectionScreen(onProfileSelected: (_) {});
        }
        if (!value.isAuthenticated) {
          return ConnectionScreen(profile: profile);
        }
        return const HomeScreen();
      },
    );
  }
}
