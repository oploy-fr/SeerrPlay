import 'package:flutter/material.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';

enum SettingsInformationType { about, privacy, terms }

class SettingsInformationScreen extends StatelessWidget {
  const SettingsInformationScreen({required this.type, super.key});

  final SettingsInformationType type;

  @override
  Widget build(BuildContext context) {
    final document = _document(context);
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DocumentHeader(document: document),
                const SizedBox(height: 30),
                for (final section in document.sections) ...[
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    section.body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.72),
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _InformationDocument _document(BuildContext context) {
    return switch (type) {
      SettingsInformationType.about => _InformationDocument(
        icon: Icons.auto_awesome_outlined,
        title: context.tr('About SeerrPlay'),
        introduction: context.tr(
          'One application to discover, request, watch and download media from your own servers.',
        ),
        sections: [
          _InformationSection(
            title: context.tr('Independent application'),
            body: context.tr(
              'SeerrPlay is an independent client. It is not an official Seerr, Plex, Jellyfin or Emby application and does not host a media catalog.',
            ),
          ),
          _InformationSection(
            title: context.tr('Direct architecture'),
            body: context.tr(
              'The application connects directly to the Seerr and media server addresses configured in each profile, without a SeerrPlay intermediary server.',
            ),
          ),
          _InformationSection(
            title: context.tr('Designed for personal libraries'),
            body: context.tr(
              'SeerrPlay is intended for media servers and libraries that you own or are authorized to access.',
            ),
          ),
        ],
      ),
      SettingsInformationType.privacy => _InformationDocument(
        icon: Icons.privacy_tip_outlined,
        title: context.tr('Privacy policy'),
        introduction: context.tr(
          'SeerrPlay is designed to minimize data collection and keep control with the user.',
        ),
        sections: [
          _InformationSection(
            title: context.tr('No tracking or advertising'),
            body: context.tr(
              'SeerrPlay does not include advertising, analytics or cross-application tracking.',
            ),
          ),
          _InformationSection(
            title: context.tr('Google Cast'),
            body: context.tr(
              'When Google Cast is available, the Google Cast SDK may send technical application, device discovery and cast session information to Google. Media server credentials are not included.',
            ),
          ),
          _InformationSection(
            title: context.tr('Direct server communication'),
            body: context.tr(
              'Requests, searches and playback information are exchanged directly with the Seerr and media servers configured by the user.',
            ),
          ),
          _InformationSection(
            title: context.tr('On-device storage'),
            body: context.tr(
              'Profiles and preferences are stored on the device. Authentication secrets are stored using the secure storage provided by the operating system.',
            ),
          ),
          _InformationSection(
            title: context.tr('Downloads and notifications'),
            body: context.tr(
              'Offline media is stored on the device. Request notifications are generated from periodic checks performed by the application.',
            ),
          ),
          _InformationSection(
            title: context.tr('Data deletion'),
            body: context.tr(
              'Deleting a profile removes its local connection information and credentials. Offline downloads can be removed from the Downloads page.',
            ),
          ),
        ],
      ),
      SettingsInformationType.terms => _InformationDocument(
        icon: Icons.description_outlined,
        title: context.tr('Terms of use'),
        introduction: context.tr(
          'Use of SeerrPlay requires access to compatible servers supplied by the user.',
        ),
        sections: [
          _InformationSection(
            title: context.tr('Authorized access only'),
            body: context.tr(
              'You must only connect to servers, libraries and media that you own or are authorized to use.',
            ),
          ),
          _InformationSection(
            title: context.tr('No media service'),
            body: context.tr(
              'SeerrPlay does not sell, provide or host films, series, subscriptions or download sources.',
            ),
          ),
          _InformationSection(
            title: context.tr('Third-party services'),
            body: context.tr(
              'Availability and operation depend on the Seerr and media servers configured by the user and on their respective administrators.',
            ),
          ),
          _InformationSection(
            title: context.tr('User responsibility'),
            body: context.tr(
              'The user is responsible for server security, content rights, network configuration and compliance with applicable laws.',
            ),
          ),
        ],
      ),
    };
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.document});

  final _InformationDocument document;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.09)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.violet.withValues(alpha: 0.2), Colors.transparent],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(document.icon, color: AppColors.white, size: 32),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  document.introduction,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.65),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationDocument {
  const _InformationDocument({
    required this.icon,
    required this.title,
    required this.introduction,
    required this.sections,
  });

  final IconData icon;
  final String title;
  final String introduction;
  final List<_InformationSection> sections;
}

class _InformationSection {
  const _InformationSection({required this.title, required this.body});

  final String title;
  final String body;
}
