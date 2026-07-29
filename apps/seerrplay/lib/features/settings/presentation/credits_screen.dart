import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seerrplay/core/config/app_links.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static final _projects = <_CreditProject>[
    _CreditProject(
      name: 'Seerr',
      description:
          'Media discovery and request management for personal media servers.',
      url: Uri.parse('https://github.com/seerr-team/seerr'),
    ),
    _CreditProject(
      name: 'Jellyfin',
      description: 'Open-source media server and playback APIs.',
      url: Uri.parse('https://jellyfin.org'),
    ),
    _CreditProject(
      name: 'Plex',
      description: 'Personal media server and playback platform.',
      url: Uri.parse('https://www.plex.tv'),
    ),
    _CreditProject(
      name: 'Emby',
      description: 'Personal media server and playback platform.',
      url: Uri.parse('https://emby.media'),
    ),
    _CreditProject(
      name: 'Flutter',
      description: 'Cross-platform application framework.',
      url: Uri.parse('https://flutter.dev'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Credits'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TmdbAttribution(onTap: () => _open(context, _tmdbUrl)),
                const SizedBox(height: 34),
                Text(
                  context.tr('Projects and services'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    'SeerrPlay interoperates with these independent projects and services.',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.62),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: AppColors.white.withValues(alpha: 0.09),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < _projects.length;
                        index++
                      ) ...[
                        _CreditRow(
                          project: _projects[index],
                          onTap: () => _open(context, _projects[index].url),
                        ),
                        if (index < _projects.length - 1)
                          Divider(
                            height: 1,
                            color: AppColors.white.withValues(alpha: 0.08),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                OutlinedButton.icon(
                  onPressed: () => _open(context, AppLinks.source),
                  icon: const Icon(Icons.code_rounded),
                  label: Text(context.tr('View SeerrPlay on GitHub')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final _tmdbUrl = Uri.parse('https://www.themoviedb.org');

  Future<void> _open(BuildContext context, Uri url) async {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Unable to open this link.'))),
    );
  }
}

class _TmdbAttribution extends StatelessWidget {
  const _TmdbAttribution({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.09)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF90CEA1).withValues(alpha: 0.13),
                const Color(0xFF00B3E5).withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SvgPicture.asset(
                'assets/credits/tmdb_logo.svg',
                width: 190,
                semanticsLabel: 'TMDB',
              ),
              const SizedBox(height: 18),
              Text(
                'This product uses the TMDB API but is not endorsed or certified by TMDB.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.76),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.project, required this.onTap});

  final _CreditProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      title: Text(
        project.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        context.tr(project.description),
        style: TextStyle(color: AppColors.white.withValues(alpha: 0.54)),
      ),
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 19,
        color: AppColors.white.withValues(alpha: 0.4),
      ),
      onTap: onTap,
    );
  }
}

class _CreditProject {
  const _CreditProject({
    required this.name,
    required this.description,
    required this.url,
  });

  final String name;
  final String description;
  final Uri url;
}
