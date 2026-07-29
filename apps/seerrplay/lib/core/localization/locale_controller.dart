import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends AsyncNotifier<Locale?> {
  static const preferenceKey = 'app_locale_v1';

  @override
  Future<Locale?> build() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(preferenceKey);
    return code == null ? null : Locale(code);
  }

  Future<void> select(String languageCode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(preferenceKey, languageCode);
    state = AsyncData(Locale(languageCode));
  }
}
