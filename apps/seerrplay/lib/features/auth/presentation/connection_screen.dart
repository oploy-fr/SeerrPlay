import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/core/widgets/seerr_brand_logo.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/service_connector.dart';
import 'package:seerrplay/features/plex/data/plex_client.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:seerrplay/features/profiles/presentation/profile_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({required this.profile, super.key});

  final ConnectionProfile profile;

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _seerrLogin = TextEditingController();
  final _seerrPassword = TextEditingController();
  final _mediaServerLogin = TextEditingController();
  final _mediaServerPassword = TextEditingController();
  SeerrLoginMethod _method = SeerrLoginMethod.mediaServer;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _seerrLogin.dispose();
    _seerrPassword.dispose();
    _mediaServerLogin.dispose();
    _mediaServerPassword.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.tr('Required field')
      : null;

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final usesMediaServerLogin = _method == SeerrLoginMethod.mediaServer;
      final connector = const ServiceConnector();
      final prepared = await connector.prepareSeerr(
        seerrBaseUrl: widget.profile.seerrBaseUrl,
        method: _method,
        login: _seerrLogin.text.trim(),
        password: _seerrPassword.text,
        profileId: widget.profile.id,
        authorizePlex: _authorizePlex,
      );
      final credentials = await connector.connectMediaServer(
        profileId: widget.profile.id,
        mediaServerBaseUrl: widget.profile.mediaServerBaseUrl,
        login: usesMediaServerLogin
            ? _seerrLogin.text.trim()
            : _mediaServerLogin.text.trim(),
        password: usesMediaServerLogin
            ? _seerrPassword.text
            : _mediaServerPassword.text,
        seerr: prepared,
      );
      await ref
          .read(appSessionControllerProvider.notifier)
          .saveCredentials(credentials);
    } catch (error) {
      if (mounted) {
        final connectionError = error is ServiceConnectionException
            ? error
            : null;
        setState(
          () => _error = context.tr(
            ServiceConnector.friendlyError(error),
            arguments: connectionError?.messageArguments ?? const {},
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _authorizePlex(PlexPin pin) async {
    final opened = await launchUrl(
      pin.authenticationUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const FormatException('Unable to open Plex authentication.');
    }
    return PlexAuthentication(
      clientIdentifier: widget.profile.id,
    ).waitForToken(pin.id);
  }

  @override
  Widget build(BuildContext context) {
    final usesMediaServerLogin = _method == SeerrLoginMethod.mediaServer;
    final serverName = widget.profile.mediaServerType.displayName;
    final usesPlex = widget.profile.mediaServerType == MediaServerType.plex;
    return Scaffold(
      appBar: AppBar(title: const SeerrBrandLogo(compact: true)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ProfileAvatar(
                          avatarIndex: widget.profile.avatarIndex,
                          size: 52,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.profile.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      context.tr('Reconnect services'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Seerr · ${widget.profile.seerrBaseUrl}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    Text(
                      '$serverName · ${widget.profile.mediaServerBaseUrl}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<SeerrLoginMethod>(
                      segments: [
                        ButtonSegment(
                          value: SeerrLoginMethod.mediaServer,
                          label: Text(serverName),
                        ),
                        ButtonSegment(
                          value: SeerrLoginMethod.local,
                          label: Text(context.tr('Seerr account')),
                        ),
                      ],
                      selected: {_method},
                      onSelectionChanged: _loading
                          ? null
                          : (value) => setState(() => _method = value.first),
                    ),
                    const SizedBox(height: 18),
                    _LoginField(
                      controller: _seerrLogin,
                      label: usesMediaServerLogin
                          ? context.tr(
                              usesPlex
                                  ? 'Plex opens secure authentication'
                                  : '{service} username',
                              arguments: {'service': serverName},
                            )
                          : context.tr('Seerr email'),
                      validator: usesPlex && usesMediaServerLogin
                          ? (_) => null
                          : _required,
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: _seerrPassword,
                      label: context.tr('Password'),
                      obscure: _obscure,
                      validator: usesPlex && usesMediaServerLogin
                          ? (_) => null
                          : _required,
                      onToggle: () => setState(() => _obscure = !_obscure),
                    ),
                    if (usesPlex) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.open_in_new_rounded,
                          color: AppColors.cyan,
                        ),
                        title: Text(context.tr('Secure Plex authentication')),
                        subtitle: Text(
                          context.tr(
                            'The Plex website opens to approve SeerrPlay.',
                          ),
                        ),
                      ),
                    ] else if (usesMediaServerLogin) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.link_outlined,
                          color: AppColors.cyan,
                        ),
                        title: Text(
                          context.tr(
                            'Linked {service} account',
                            arguments: {'service': serverName},
                          ),
                        ),
                        subtitle: Text(
                          context.tr(
                            'These credentials sign in to Seerr and {service}.',
                            arguments: {'service': serverName},
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      Text(
                        context.tr(
                          '{service} account',
                          arguments: {'service': serverName},
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _LoginField(
                        controller: _mediaServerLogin,
                        label: context.tr(
                          '{service} username',
                          arguments: {'service': serverName},
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      _PasswordField(
                        controller: _mediaServerPassword,
                        label: context.tr(
                          '{service} password',
                          arguments: {'service': serverName},
                        ),
                        obscure: _obscure,
                        validator: _required,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loading ? null : _connect,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(context.tr('Sign in')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.label,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.person_outline_rounded),
      ),
      validator: validator,
      textInputAction: TextInputAction.next,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.validator,
    this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final FormFieldValidator<String> validator;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: onToggle == null
            ? null
            : IconButton(
                onPressed: onToggle,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
      ),
      validator: validator,
    );
  }
}
