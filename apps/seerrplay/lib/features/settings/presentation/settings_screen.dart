import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:seerrplay/core/config/app_links.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/core/widgets/app_page_layout.dart';
import 'package:seerrplay/features/notifications/application/request_notification_service.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:seerrplay/features/profiles/presentation/profile_avatar.dart';
import 'package:seerrplay/features/settings/presentation/credits_screen.dart';
import 'package:seerrplay/features/settings/presentation/settings_information_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.activeProfile,
    required this.profiles,
    required this.connectionStatus,
    required this.onSelectProfile,
    required this.onAddProfile,
    required this.onReconnect,
    required this.onDeleteProfile,
    required this.onContentRestrictionsChanged,
    super.key,
  });

  final ConnectionProfile activeProfile;
  final List<ConnectionProfile> profiles;
  final String connectionStatus;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onAddProfile;
  final VoidCallback onReconnect;
  final VoidCallback onDeleteProfile;
  final void Function(bool enabled, int maximumAge)
  onContentRestrictionsChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppPageAppBar(title: Text(context.tr('Settings'))),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? AppPageLayout.horizontalInset(context, compact: 20) : 20,
                14,
                wide ? AppPageLayout.horizontalInset(context, compact: 20) : 20,
                128,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SettingsHero(
                        activeProfile: activeProfile,
                        connectionStatus: connectionStatus,
                      ),
                      SizedBox(height: wide ? 44 : 34),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _primaryColumn(context)),
                            const SizedBox(width: 46),
                            Expanded(child: _secondaryColumn(context)),
                          ],
                        )
                      else ...[
                        _primaryColumn(context),
                        const SizedBox(height: 48),
                        _secondaryColumn(context),
                      ],
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

  Widget _primaryColumn(BuildContext context) {
    return Column(
      children: [
        _ProfileSection(
          activeProfile: activeProfile,
          profiles: profiles,
          onSelectProfile: onSelectProfile,
          onAddProfile: onAddProfile,
        ),
        const SizedBox(height: 48),
        _PreferencesSection(
          activeProfile: activeProfile,
          onContentRestrictionsChanged: onContentRestrictionsChanged,
        ),
        const SizedBox(height: 48),
        _ConnectionSection(
          activeProfile: activeProfile,
          connectionStatus: connectionStatus,
          onReconnect: onReconnect,
        ),
      ],
    );
  }

  Widget _secondaryColumn(BuildContext context) {
    return Column(
      children: [
        _PrivacySection(onDeleteProfile: () => _confirmDelete(context)),
        const SizedBox(height: 48),
        _AboutSection(
          activeProfile: activeProfile,
          connectionStatus: connectionStatus,
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete this profile?')),
        content: Text(
          context.tr(
            'The “{name}” profile and its sign-in information will be removed from this device.',
            arguments: {'name': activeProfile.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteProfile();
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({
    required this.activeProfile,
    required this.connectionStatus,
  });

  final ConnectionProfile activeProfile;
  final String connectionStatus;

  @override
  Widget build(BuildContext context) {
    final connected = connectionStatus == context.tr('Connected');
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.09)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.violet.withValues(alpha: 0.22),
            AppColors.magenta.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            avatarIndex: activeProfile.avatarIndex,
            size: 62,
            selected: true,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeProfile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('Your media space'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ConnectionPill(connected: connected, label: connectionStatus),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.activeProfile,
    required this.profiles,
    required this.onSelectProfile,
    required this.onAddProfile,
  });

  final ConnectionProfile activeProfile;
  final List<ConnectionProfile> profiles;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onAddProfile;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.people_outline_rounded,
      title: context.tr('Profiles'),
      subtitle: context.tr('Choose the servers and account currently in use.'),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: profiles.length + 1,
          separatorBuilder: (context, index) => const SizedBox(width: 18),
          itemBuilder: (context, index) {
            if (index == profiles.length) {
              return _AddProfileButton(onPressed: onAddProfile);
            }
            final profile = profiles[index];
            final selected = profile.id == activeProfile.id;
            return _ProfileButton(
              profile: profile,
              selected: selected,
              onPressed: () => onSelectProfile(profile.id),
            );
          },
        ),
      ),
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    required this.activeProfile,
    required this.onContentRestrictionsChanged,
  });

  final ConnectionProfile activeProfile;
  final void Function(bool enabled, int maximumAge)
  onContentRestrictionsChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.tune_rounded,
      title: context.tr('Application'),
      subtitle: context.tr('Language and notification preferences.'),
      child: _SettingsRows(
        children: [
          const _LanguageRow(),
          if (supportsBackgroundRequestPolling) const _NotificationsRow(),
          _ChildModeRow(
            profile: activeProfile,
            onChanged: onContentRestrictionsChanged,
          ),
        ],
      ),
    );
  }
}

class _ChildModeRow extends StatelessWidget {
  const _ChildModeRow({required this.profile, required this.onChanged});

  static const ages = [6, 9, 12, 14, 16, 18];

  final ConnectionProfile profile;
  final void Function(bool enabled, int maximumAge) onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      icon: Icons.child_care_rounded,
      title: context.tr('Child mode'),
      subtitle: context.tr(
        'Only shows content whose age rating is known and allowed.',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile.childMode)
            PopupMenuButton<int>(
              initialValue: profile.maximumContentAge,
              tooltip: context.tr('Maximum age rating'),
              onSelected: (age) => onChanged(true, age),
              itemBuilder: (context) => [
                for (final age in ages)
                  PopupMenuItem(
                    value: age,
                    child: Text(
                      context.tr('Up to age {age}', arguments: {'age': age}),
                    ),
                  ),
              ],
              child: _TrailingValue(label: '≤ ${profile.maximumContentAge}'),
            ),
          Switch(
            value: profile.childMode,
            onChanged: (enabled) =>
                onChanged(enabled, profile.maximumContentAge),
          ),
        ],
      ),
    );
  }
}

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({
    required this.activeProfile,
    required this.connectionStatus,
    required this.onReconnect,
  });

  final ConnectionProfile activeProfile;
  final String connectionStatus;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.hub_outlined,
      title: context.tr('Direct connections'),
      subtitle: context.tr(
        'SeerrPlay communicates directly with the servers in this profile.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsRows(
            children: [
              _ServerRow(
                name: 'Seerr',
                icon: Icons.search_rounded,
                url: activeProfile.seerrBaseUrl,
              ),
              _ServerRow(
                name: activeProfile.mediaServerType.displayName,
                icon: Icons.play_circle_outline_rounded,
                url: activeProfile.mediaServerBaseUrl,
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onReconnect,
            icon: const Icon(Icons.sync_rounded),
            label: Text(context.tr('Reconnect services')),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.onDeleteProfile});

  final VoidCallback onDeleteProfile;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.shield_outlined,
      title: context.tr('Privacy and data'),
      subtitle: context.tr('Your data stays under your control.'),
      child: _SettingsRows(
        children: [
          _NavigationRow(
            icon: Icons.privacy_tip_outlined,
            title: context.tr('Privacy policy'),
            subtitle: context.tr('How SeerrPlay handles your data.'),
            onTap: () =>
                _openInformation(context, SettingsInformationType.privacy),
          ),
          _ExternalLinkRow(
            icon: Icons.public_rounded,
            title: context.tr('Public privacy policy'),
            subtitle: context.tr('Open the policy published on the web.'),
            url: AppLinks.privacy,
          ),
          _InformationRow(
            icon: Icons.lan_outlined,
            title: context.tr('Local network access'),
            subtitle: context.tr(
              'Used only to reach the Seerr and media servers you configure.',
            ),
          ),
          _InformationRow(
            icon: Icons.cloud_off_outlined,
            title: context.tr('No SeerrPlay cloud'),
            subtitle: context.tr(
              'Credentials and preferences are stored on this device.',
            ),
          ),
          _NavigationRow(
            icon: Icons.delete_outline_rounded,
            title: context.tr('Delete local profile data'),
            subtitle: context.tr(
              'Removes this profile and its credentials from this device.',
            ),
            destructive: true,
            onTap: onDeleteProfile,
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.activeProfile,
    required this.connectionStatus,
  });

  final ConnectionProfile activeProfile;
  final String connectionStatus;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      icon: Icons.info_outline_rounded,
      title: context.tr('About'),
      subtitle: context.tr('Information, legal documents and diagnostics.'),
      child: _SettingsRows(
        children: [
          _NavigationRow(
            icon: Icons.auto_awesome_outlined,
            title: context.tr('About SeerrPlay'),
            subtitle: context.tr(
              'Independent client for your personal media servers.',
            ),
            onTap: () =>
                _openInformation(context, SettingsInformationType.about),
          ),
          _NavigationRow(
            icon: Icons.description_outlined,
            title: context.tr('Terms of use'),
            subtitle: context.tr('Rules for using SeerrPlay responsibly.'),
            onTap: () =>
                _openInformation(context, SettingsInformationType.terms),
          ),
          _NavigationRow(
            icon: Icons.code_rounded,
            title: context.tr('Credits'),
            subtitle: context.tr(
              'Projects, services and data sources used by SeerrPlay.',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const CreditsScreen(),
              ),
            ),
          ),
          _NavigationRow(
            icon: Icons.article_outlined,
            title: context.tr('Open-source licenses'),
            subtitle: context.tr('Libraries used to build the application.'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'SeerrPlay',
              applicationIcon: const _LicenseLogo(),
            ),
          ),
          _ExternalLinkRow(
            icon: Icons.support_agent_rounded,
            title: context.tr('Support'),
            subtitle: context.tr('Help, contact and issue reporting.'),
            url: AppLinks.support,
          ),
          _PackageInformationRow(
            activeProfile: activeProfile,
            connectionStatus: connectionStatus,
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.violet.withValues(alpha: 0.14),
              ),
              child: Icon(icon, size: 20, color: AppColors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.48),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _SettingsRows extends StatelessWidget {
  const _SettingsRows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AppColors.white.withValues(alpha: 0.09),
          ),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Divider(
                height: 1,
                indent: 54,
                color: AppColors.white.withValues(alpha: 0.08),
              ),
          ],
        ],
      ),
    );
  }
}

class _LanguageRow extends ConsumerWidget {
  const _LanguageRow();

  static const _languages = <String, String>{
    'fr': 'French',
    'en': 'English',
    'es': 'Spanish',
    'it': 'Italian',
    'de': 'German',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCode =
        ref.watch(localeControllerProvider).value?.languageCode ?? 'en';
    return _SettingsRowShell(
      icon: Icons.translate_rounded,
      title: context.tr('Language'),
      trailing: PopupMenuButton<String>(
        initialValue: currentCode,
        tooltip: context.tr('Language'),
        onSelected: (code) =>
            ref.read(localeControllerProvider.notifier).select(code),
        itemBuilder: (context) => [
          for (final language in _languages.entries)
            PopupMenuItem(
              value: language.key,
              child: Row(
                children: [
                  Expanded(child: Text(context.tr(language.value))),
                  if (language.key == currentCode)
                    const Icon(Icons.check_rounded, size: 18),
                ],
              ),
            ),
        ],
        child: _TrailingValue(
          label: context.tr(_languages[currentCode] ?? 'English'),
        ),
      ),
    );
  }
}

class _NotificationsRow extends ConsumerWidget {
  const _NotificationsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(requestNotificationsControllerProvider);
    final enabled = notifications.value ?? false;
    return _SettingsRowShell(
      icon: Icons.notifications_none_rounded,
      title: context.tr('Request notifications'),
      subtitle: context.tr(
        'Periodically checks Seerr for approval and availability updates. Your device may delay background checks.',
      ),
      trailing: notifications.isLoading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: enabled,
              onChanged: (value) async {
                final result = await ref
                    .read(requestNotificationsControllerProvider.notifier)
                    .setEnabled(value);
                if (value && !result && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.tr(
                          'Notifications are disabled in system settings.',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({required this.name, required this.icon, required this.url});

  final String name;
  final IconData icon;
  final Uri url;

  @override
  Widget build(BuildContext context) {
    final secure = url.scheme == 'https';
    return _SettingsRowShell(
      icon: icon,
      title: name,
      subtitle: url.toString(),
      trailing: Tooltip(
        message: context.tr(
          secure
              ? 'Secure connection (HTTPS)'
              : 'Unencrypted connection (HTTP)',
        ),
        child: Icon(
          secure ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
          size: 18,
          color: secure ? const Color(0xFF4ADE80) : AppColors.magenta,
        ),
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      destructive: destructive,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: destructive
            ? Theme.of(context).colorScheme.error
            : AppColors.white.withValues(alpha: 0.38),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(icon: icon, title: title, subtitle: subtitle);
  }
}

class _ExternalLinkRow extends StatelessWidget {
  const _ExternalLinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Uri url;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowShell(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () async {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Unable to open this link.'))),
        );
      },
      trailing: Icon(
        Icons.open_in_new_rounded,
        size: 19,
        color: AppColors.white.withValues(alpha: 0.38),
      ),
    );
  }
}

class _PackageInformationRow extends StatelessWidget {
  const _PackageInformationRow({
    required this.activeProfile,
    required this.connectionStatus,
  });

  final ConnectionProfile activeProfile;
  final String connectionStatus;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? '—'
            : context.tr(
                'Version {version} ({build})',
                arguments: {'version': info.version, 'build': info.buildNumber},
              );
        return _SettingsRowShell(
          icon: Icons.developer_mode_rounded,
          title: version,
          subtitle: context.tr('Copy diagnostics without credentials.'),
          onTap: info == null
              ? null
              : () async {
                  final diagnostics = [
                    'SeerrPlay ${info.version} (${info.buildNumber})',
                    'Platform: ${defaultTargetPlatform.name}',
                    'Profile: ${activeProfile.name}',
                    'Status: $connectionStatus',
                    'Seerr: ${activeProfile.seerrBaseUrl}',
                    '${activeProfile.mediaServerType.displayName}: ${activeProfile.mediaServerBaseUrl}',
                  ].join('\n');
                  await Clipboard.setData(ClipboardData(text: diagnostics));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('Diagnostics copied.'))),
                  );
                },
          trailing: const Icon(Icons.copy_rounded, size: 19),
        );
      },
    );
  }
}

class _SettingsRowShell extends StatelessWidget {
  const _SettingsRowShell({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : AppColors.white.withValues(alpha: 0.7);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(icon, size: 21, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: destructive ? color : AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.46),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.profile,
    required this.selected,
    required this.onPressed,
  });

  final ConnectionProfile profile;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            ProfileAvatar(
              avatarIndex: profile.avatarIndex,
              size: 58,
              selected: selected,
            ),
            const SizedBox(height: 7),
            Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.white : Colors.white54,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProfileButton extends StatelessWidget {
  const _AddProfileButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.22),
                ),
              ),
              child: const Icon(Icons.add_rounded),
            ),
            const SizedBox(height: 7),
            Text(
              context.tr('Add profile'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.connected, required this.label});

  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? const Color(0xFF4ADE80)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailingValue extends StatelessWidget {
  const _TrailingValue({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.expand_more_rounded, color: Colors.white54),
      ],
    );
  }
}

class _LicenseLogo extends StatelessWidget {
  const _LicenseLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.brandGradient,
      ),
      alignment: Alignment.center,
      child: const Text(
        'S',
        style: TextStyle(
          color: AppColors.white,
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

void _openInformation(
  BuildContext context,
  SettingsInformationType informationType,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => SettingsInformationScreen(type: informationType),
    ),
  );
}
