import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/service_connector.dart';
import 'package:seerrplay/features/plex/data/plex_client.dart';
import 'package:seerrplay/features/profiles/application/profiles_controller.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:seerrplay/features/profiles/domain/server_address.dart';
import 'package:seerrplay/features/profiles/presentation/profile_avatar.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileId = const Uuid().v4();
  final _name = TextEditingController();
  final _seerrUrl = TextEditingController();
  final _seerrPort = TextEditingController();
  final _seerrLogin = TextEditingController();
  final _seerrPassword = TextEditingController();
  final _mediaServerUrl = TextEditingController();
  final _mediaServerPort = TextEditingController();
  final _mediaServerLogin = TextEditingController();
  final _mediaServerPassword = TextEditingController();
  SeerrLoginMethod _method = SeerrLoginMethod.mediaServer;
  String _seerrScheme = 'https';
  String _mediaServerScheme = 'https';
  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _errorCode;
  String? _status;
  bool _statusIsSuccess = false;
  bool _useSeparateMediaServerCredentials = false;
  SeerrConnectionPreparation? _preparedSeerr;
  MediaServerType? _detectedMediaServerType;
  int _avatarIndex = 0;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _seerrUrl,
      _seerrPort,
      _seerrLogin,
      _seerrPassword,
      _mediaServerUrl,
      _mediaServerPort,
      _mediaServerLogin,
      _mediaServerPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.tr('Required field')
      : null;

  String? _domain(String? value, String scheme) {
    if (_required(value) case final error?) return error;
    try {
      ServerAddress.parse(input: value!, fallbackScheme: scheme);
      return null;
    } on FormatException {
      return context.tr('Invalid domain, example: jellyfin.example.com');
    }
  }

  String? _port(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final port = int.tryParse(value.trim());
    return port == null || port < 1 || port > 65535
        ? context.tr('Port between 1 and 65535')
        : null;
  }

  Uri _serverUri({
    required TextEditingController domain,
    required TextEditingController port,
    required String scheme,
  }) {
    return ServerAddress.parse(
      input: domain.text,
      fallbackScheme: scheme,
      customPort: port.text,
    ).uri;
  }

  void _clearFeedback() {
    _error = null;
    _errorCode = null;
    _status = null;
    _statusIsSuccess = false;
  }

  void _showError(Object error) {
    final typed = error is ServiceConnectionException ? error : null;
    setState(() {
      _error = context.tr(
        ServiceConnector.friendlyError(error),
        arguments: typed?.messageArguments ?? const {},
      );
      _errorCode = typed?.code;
      _status = null;
      _statusIsSuccess = false;
    });
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_step == 0) {
      setState(() {
        _clearFeedback();
        _step = 1;
      });
      return;
    }
    if (_step == 1) await _prepareSeerr();
  }

  Future<void> _prepareSeerr() async {
    setState(() {
      _loading = true;
      _clearFeedback();
      _preparedSeerr = null;
      _status = context.tr('Checking the Seerr server…');
    });
    try {
      final seerrBaseUrl = _serverUri(
        domain: _seerrUrl,
        port: _seerrPort,
        scheme: _seerrScheme,
      );
      final prepared = await const ServiceConnector().prepareSeerr(
        seerrBaseUrl: seerrBaseUrl,
        method: _method,
        login: _seerrLogin.text.trim(),
        password: _seerrPassword.text,
        profileId: _profileId,
        authorizePlex: _authorizePlex,
        onStageChanged: (stage) {
          if (!mounted) return;
          setState(() {
            _status = switch (stage) {
              SeerrPreparationStage.checkingServer => context.tr(
                'Checking the Seerr server…',
              ),
              SeerrPreparationStage.signingIn => context.tr(
                'Signing in to Seerr…',
              ),
              SeerrPreparationStage.signingInToPlex => context.tr(
                'Approve the connection in Plex…',
              ),
              SeerrPreparationStage.discoveringMediaServer => context.tr(
                'Looking for your media server automatically…',
              ),
            };
          });
        },
      );
      if (!mounted) return;
      final discovered = prepared.discoveredMediaServer;
      final serverName = prepared.mediaServerType.displayName;
      setState(() {
        _preparedSeerr = prepared;
        _detectedMediaServerType = prepared.mediaServerType;
        _step = 2;
        if (discovered != null) {
          _mediaServerScheme = discovered.scheme;
          _mediaServerUrl.text = discovered.host + discovered.path;
          _mediaServerPort.text = discovered.port?.toString() ?? '';
          _status = context.tr(
            '{service} server found automatically.',
            arguments: {'service': serverName},
          );
          _statusIsSuccess = true;
        } else {
          _status = context.tr(
            'Seerr does not publish the {service} address. Enter it manually.',
            arguments: {'service': serverName},
          );
          _statusIsSuccess = false;
        }
      });
      if (discovered != null &&
          (_method == SeerrLoginMethod.mediaServer ||
              prepared.mediaServerType == MediaServerType.plex)) {
        setState(() {
          _status = context.tr(
            '{service} server found. Checking the connection…',
            arguments: {'service': serverName},
          );
          _statusIsSuccess = false;
        });
        try {
          await _connectMediaServerAndComplete(
            prepared: prepared,
            login: _seerrLogin.text.trim(),
            password: _seerrPassword.text,
          );
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _useSeparateMediaServerCredentials = true;
            _mediaServerLogin.text = _seerrLogin.text.trim();
            _mediaServerPassword.text = _seerrPassword.text;
          });
          _showError(error);
        }
      }
    } catch (error) {
      if (mounted) _showError(error);
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
    if (mounted) {
      setState(() {
        _status = context.tr(
          'Approve SeerrPlay in Plex, then return to the app…',
        );
        _statusIsSuccess = false;
      });
    }
    return PlexAuthentication(
      clientIdentifier: _profileId,
    ).waitForToken(pin.id);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final prepared = _preparedSeerr;
    if (prepared == null) {
      setState(() => _step = 1);
      return;
    }
    setState(() {
      _loading = true;
      _clearFeedback();
      _status = context.tr(
        'Signing in to {service}…',
        arguments: {'service': prepared.mediaServerType.displayName},
      );
    });
    try {
      final reuseSeerrCredentials =
          _method == SeerrLoginMethod.mediaServer &&
          !_useSeparateMediaServerCredentials;
      await _connectMediaServerAndComplete(
        prepared: prepared,
        login: reuseSeerrCredentials
            ? _seerrLogin.text.trim()
            : _mediaServerLogin.text.trim(),
        password: reuseSeerrCredentials
            ? _seerrPassword.text
            : _mediaServerPassword.text,
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectMediaServerAndComplete({
    required SeerrConnectionPreparation prepared,
    required String login,
    required String password,
  }) async {
    final profile = ConnectionProfile(
      id: _profileId,
      name: _name.text.trim(),
      seerrBaseUrl: _serverUri(
        domain: _seerrUrl,
        port: _seerrPort,
        scheme: _seerrScheme,
      ),
      mediaServerBaseUrl: _serverUri(
        domain: _mediaServerUrl,
        port: _mediaServerPort,
        scheme: _mediaServerScheme,
      ),
      mediaServerType: prepared.mediaServerType,
      avatarIndex: _avatarIndex,
    );
    final credentials = await const ServiceConnector().connectMediaServer(
      profileId: profile.id,
      mediaServerBaseUrl: profile.mediaServerBaseUrl,
      login: login,
      password: password,
      seerr: prepared,
    );
    if (!mounted) return;
    setState(() {
      _status = context.tr(
        '{service} server found and connected.',
        arguments: {'service': prepared.mediaServerType.displayName},
      );
      _statusIsSuccess = true;
      _error = null;
      _errorCode = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await ref
        .read(credentialStoreProvider)
        .writeCredentials(profile.id, credentials);
    await ref
        .read(profilesControllerProvider.notifier)
        .addProfile(
          id: profile.id,
          name: profile.name,
          seerrUrl: profile.seerrBaseUrl.toString(),
          mediaServerUrl: profile.mediaServerBaseUrl.toString(),
          mediaServerType: profile.mediaServerType,
          avatarIndex: profile.avatarIndex,
        );
    widget.onCompleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('Profile name'),
      context.tr('Seerr server'),
      context.tr(
        '{service} server',
        arguments: {
          'service': _detectedMediaServerType?.displayName ?? 'Media',
        },
      ),
    ];
    final subtitles = [
      context.tr('Home, Travel, Family…'),
      context.tr('Request server address and account'),
      context.tr('Playback server address'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('New profile'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 42),
                children: [
                  Row(
                    children: [
                      for (var index = 0; index < 3; index++) ...[
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 3,
                            decoration: BoxDecoration(
                              color: index <= _step
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (index < 2) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    titles[_step],
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitles[_step],
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: switch (_step) {
                        0 => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Choose an avatar'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 74,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: profileAvatarCount,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) => InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () =>
                                      setState(() => _avatarIndex = index),
                                  child: ProfileAvatar(
                                    avatarIndex: index,
                                    size: 66,
                                    selected: _avatarIndex == index,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _name,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: context.tr('Name'),
                                hintText: context.tr('Home profile name'),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                ),
                              ),
                              validator: _required,
                            ),
                          ],
                        ),
                        1 => Column(
                          children: [
                            _AddressFields(
                              domain: _seerrUrl,
                              port: _seerrPort,
                              scheme: _seerrScheme,
                              onSchemeChanged: (value) =>
                                  setState(() => _seerrScheme = value),
                              domainHint: 'seerr.example.com',
                              portHint: '5055',
                              domainValidator: (value) =>
                                  _domain(value, _seerrScheme),
                              portValidator: _port,
                            ),
                            const SizedBox(height: 18),
                            SegmentedButton<SeerrLoginMethod>(
                              segments: [
                                ButtonSegment(
                                  value: SeerrLoginMethod.mediaServer,
                                  label: Text(context.tr('Media server')),
                                ),
                                ButtonSegment(
                                  value: SeerrLoginMethod.local,
                                  label: Text(context.tr('Seerr email')),
                                ),
                              ],
                              selected: {_method},
                              onSelectionChanged: (value) => setState(() {
                                _method = value.first;
                                _useSeparateMediaServerCredentials = false;
                              }),
                            ),
                            const SizedBox(height: 14),
                            _LoginField(
                              controller: _seerrLogin,
                              label: _method == SeerrLoginMethod.local
                                  ? context.tr('Seerr email')
                                  : context.tr('Media server username'),
                              validator: _method == SeerrLoginMethod.local
                                  ? _required
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _PasswordField(
                              controller: _seerrPassword,
                              label: context.tr('Password'),
                              obscure: _obscure,
                              validator: _method == SeerrLoginMethod.local
                                  ? _required
                                  : null,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ],
                        ),
                        _ => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AddressFields(
                              domain: _mediaServerUrl,
                              port: _mediaServerPort,
                              scheme: _mediaServerScheme,
                              onSchemeChanged: (value) =>
                                  setState(() => _mediaServerScheme = value),
                              domainHint:
                                  '${_detectedMediaServerType?.name ?? 'media'}.example.com',
                              portHint:
                                  _detectedMediaServerType ==
                                      MediaServerType.plex
                                  ? '32400'
                                  : '8096',
                              domainValidator: (value) =>
                                  _domain(value, _mediaServerScheme),
                              portValidator: _port,
                            ),
                            const SizedBox(height: 16),
                            if (_detectedMediaServerType ==
                                MediaServerType.plex)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle_outline),
                                title: Text(
                                  context.tr('Plex account connected'),
                                ),
                                subtitle: Text(
                                  context.tr(
                                    'Authentication was approved securely through Plex.',
                                  ),
                                ),
                              )
                            else if (_method == SeerrLoginMethod.mediaServer &&
                                !_useSeparateMediaServerCredentials)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.link_rounded),
                                title: Text(
                                  context.tr('Credentials already entered'),
                                ),
                                subtitle: Text(
                                  context.tr(
                                    'The media server account selected for Seerr is reused automatically.',
                                  ),
                                ),
                              )
                            else ...[
                              _LoginField(
                                controller: _mediaServerLogin,
                                label: context.tr(
                                  '{service} username',
                                  arguments: {
                                    'service':
                                        _detectedMediaServerType?.displayName ??
                                        'Media server',
                                  },
                                ),
                                validator: _required,
                              ),
                              const SizedBox(height: 12),
                              _PasswordField(
                                controller: _mediaServerPassword,
                                label: context.tr(
                                  '{service} password',
                                  arguments: {
                                    'service':
                                        _detectedMediaServerType?.displayName ??
                                        'Media server',
                                  },
                                ),
                                obscure: _obscure,
                                validator: _required,
                              ),
                            ],
                          ],
                        ),
                      },
                    ),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 18),
                    _ConnectionFeedback(
                      message: _status!,
                      loading: _loading,
                      success: _statusIsSuccess,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 18),
                    _ConnectionFeedback(
                      message: _error!,
                      code: _errorCode,
                      isError: true,
                    ),
                  ],
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _loading
                              ? null
                              : _step == 2
                              ? _submit
                              : _continue,
                          child: _loading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  context.tr(
                                    _step == 2
                                        ? 'Create and connect'
                                        : 'Continue',
                                  ),
                                ),
                        ),
                      ),
                      if (_step > 0) ...[
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _clearFeedback();
                                  _step--;
                                }),
                          child: Text(context.tr('Back')),
                        ),
                      ],
                    ],
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

class _AddressFields extends StatelessWidget {
  const _AddressFields({
    required this.domain,
    required this.port,
    required this.scheme,
    required this.onSchemeChanged,
    required this.domainHint,
    required this.portHint,
    required this.domainValidator,
    required this.portValidator,
  });

  final TextEditingController domain;
  final TextEditingController port;
  final String scheme;
  final ValueChanged<String> onSchemeChanged;
  final String domainHint;
  final String portHint;
  final FormFieldValidator<String> domainValidator;
  final FormFieldValidator<String> portValidator;

  @override
  Widget build(BuildContext context) {
    final schemeField = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'https', label: Text('HTTPS')),
        ButtonSegment(value: 'http', label: Text('HTTP')),
      ],
      selected: {scheme},
      onSelectionChanged: (values) => onSchemeChanged(values.first),
      showSelectedIcon: false,
    );
    final domainField = TextFormField(
      controller: domain,
      keyboardType: TextInputType.url,
      autocorrect: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: context.tr('Domain or IP address'),
        hintText: domainHint,
        prefixIcon: const Icon(Icons.dns_outlined),
      ),
      validator: domainValidator,
    );
    final portField = TextFormField(
      controller: port,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: context.tr('Custom port (optional)'),
        hintText: portHint,
        prefixIcon: const Icon(Icons.settings_ethernet_rounded),
      ),
      validator: portValidator,
    );

    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (constraints.maxWidth >= 760)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 190, child: schemeField),
                const SizedBox(width: 14),
                Expanded(child: domainField),
                const SizedBox(width: 14),
                SizedBox(width: 220, child: portField),
              ],
            )
          else ...[
            schemeField,
            const SizedBox(height: 14),
            domainField,
            const SizedBox(height: 12),
            portField,
          ],
          if (scheme == 'http') ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.35),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.45),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr(
                            'HTTP does not encrypt your credentials. Use it only for a trusted local network; HTTPS is recommended.',
                          ),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionFeedback extends StatelessWidget {
  const _ConnectionFeedback({
    required this.message,
    this.code,
    this.loading = false,
    this.success = false,
    this.isError = false,
  });

  final String message;
  final String? code;
  final bool loading;
  final bool success;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError
        ? colorScheme.error
        : success
        ? const Color(0xFF42D98B)
        : colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : success
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: color,
                size: 21,
              ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  if (code != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      code!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.label,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.person_outline_rounded),
    ),
    validator: validator,
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    this.validator,
    this.onToggle,
  });
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onToggle;
  @override
  Widget build(BuildContext context) => TextFormField(
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
