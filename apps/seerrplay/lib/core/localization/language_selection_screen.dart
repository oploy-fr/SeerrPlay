import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/core/widgets/seerr_brand_logo.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  String? _selectedCode;
  bool _saving = false;

  static const _languages = <String, String>{
    'fr': 'French',
    'en': 'English',
    'es': 'Spanish',
    'it': 'Italian',
    'de': 'German',
  };

  String _deviceLanguageCode(BuildContext context) {
    final deviceCode = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase();
    return _languages.containsKey(deviceCode) ? deviceCode : 'en';
  }

  @override
  Widget build(BuildContext context) {
    final deviceCode = _deviceLanguageCode(context);
    _selectedCode ??= deviceCode;
    final codes = [
      deviceCode,
      ..._languages.keys.where((code) => code != deviceCode),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SeerrBrandLogo()),
                  const SizedBox(height: 38),
                  Text(
                    context.tr('Choose your language'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                      'Your phone language is shown first. You can change it later in Settings.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  RadioGroup<String>(
                    groupValue: _selectedCode,
                    onChanged: (value) {
                      if (!_saving) setState(() => _selectedCode = value);
                    },
                    child: Column(
                      children: [
                        for (final code in codes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RadioListTile<String>(
                              value: code,
                              controlAffinity: ListTileControlAffinity.trailing,
                              activeColor: AppColors.violet,
                              title: Text(context.tr(_languages[code]!)),
                              subtitle: code == deviceCode
                                  ? Text(context.tr('Phone language'))
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color: code == _selectedCode
                                      ? AppColors.violet
                                      : Colors.white12,
                                ),
                              ),
                              selectedTileColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await ref
                                .read(localeControllerProvider.notifier)
                                .select(_selectedCode!);
                          },
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('Continue')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
