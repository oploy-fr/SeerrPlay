import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/language_selection_screen.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/features/profiles/presentation/profile_gate.dart';

class SeerrPlayApp extends ConsumerWidget {
  const SeerrPlayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SeerrPlay',
      theme: AppTheme.dark,
      locale: locale.value,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: locale.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : locale.value == null
          ? const LanguageSelectionScreen()
          : const ProfileGate(),
    );
  }
}
