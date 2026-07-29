import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('all five languages expose the same translation catalog', () {
    final englishKeys = AppLocalizations.translationKeys('en');
    expect(englishKeys, isNotEmpty);
    for (final code in ['fr', 'es', 'it', 'de']) {
      expect(AppLocalizations.translationKeys(code), englishKeys);
    }
  });

  test('all literal interface translation keys exist in the catalog', () {
    final literalTranslation = RegExp(
      r'''(?:context\.tr|\.translate)\(\s*(['"])(.*?)\1''',
      dotAll: true,
    );
    final usedKeys = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .expand(
          (file) => literalTranslation
              .allMatches(file.readAsStringSync())
              .map((match) => match.group(2)!.replaceAll(r'\n', '\n'))
              .where((key) => !key.contains(r'$')),
        )
        .toSet();
    final missingKeys =
        usedKeys.difference(AppLocalizations.translationKeys('en')).toList()
          ..sort();

    expect(missingKeys, isEmpty, reason: 'Missing translations: $missingKeys');
  });

  test('translates labels and dynamic values', () {
    final german = AppLocalizations(const Locale('de'));
    expect(german.translate('Settings'), 'Einstellungen');
    expect(german.results(2), '2 Ergebnisse');
    expect(german.episodes(1), '1 Folge');
    expect(german.status('Download 42 %'), 'Download 42 %');
    expect(german.status('FR · AAC · 6 channels'), 'FR · AAC · 6 Kanäle');
  });

  test('persists the selected language', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(localeControllerProvider.future), isNull);
    await container.read(localeControllerProvider.notifier).select('it');
    expect(container.read(localeControllerProvider).value, const Locale('it'));
    expect(
      (await SharedPreferences.getInstance()).getString('app_locale_v1'),
      'it',
    );
  });
}
