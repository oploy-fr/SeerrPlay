import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:seerrplay/features/emby/data/emby_client.dart';
import 'package:seerrplay/features/jellyfin/data/jellyfin_client.dart';
import 'package:seerrplay/features/plex/data/plex_client.dart';
import 'package:seerrplay/features/profiles/data/credential_store.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';
import 'package:seerrplay/features/profiles/domain/server_address.dart';
import 'package:seerrplay/features/seerr/data/seerr_client.dart';

enum SeerrLoginMethod { mediaServer, local }

enum ConnectedService { seerr, mediaServer }

enum SeerrPreparationStage {
  checkingServer,
  signingIn,
  signingInToPlex,
  discoveringMediaServer,
}

enum MediaServerDiscoverySource {
  publicSettings,
  availableMedia,
  plexResources,
}

enum ConnectionFailureKind {
  invalidCredentials,
  forbidden,
  timeout,
  domainNotFound,
  tls,
  unreachable,
  invalidServer,
  server,
  invalidResponse,
}

class ServiceConnectionException implements Exception {
  const ServiceConnectionException({
    required this.service,
    required this.kind,
    this.mediaServerType,
    this.statusCode,
  });

  final ConnectedService service;
  final ConnectionFailureKind kind;
  final MediaServerType? mediaServerType;
  final int? statusCode;

  String get serviceName => service == ConnectedService.seerr
      ? 'Seerr'
      : mediaServerType?.displayName ?? 'media server';

  String get code {
    final serviceCode = service == ConnectedService.seerr
        ? 'SEERR'
        : switch (mediaServerType) {
            MediaServerType.plex => 'PLEX',
            MediaServerType.emby => 'EMBY',
            _ => 'JELLYFIN',
          };
    final failureCode = switch (kind) {
      ConnectionFailureKind.invalidCredentials => 'AUTH',
      ConnectionFailureKind.forbidden => 'FORBIDDEN',
      ConnectionFailureKind.timeout => 'TIMEOUT',
      ConnectionFailureKind.domainNotFound => 'DNS',
      ConnectionFailureKind.tls => 'TLS',
      ConnectionFailureKind.unreachable => 'UNREACHABLE',
      ConnectionFailureKind.invalidServer => 'INVALID_SERVER',
      ConnectionFailureKind.server => 'SERVER',
      ConnectionFailureKind.invalidResponse => 'INVALID_RESPONSE',
    };
    return 'SV-$serviceCode-$failureCode';
  }

  String get messageKey => switch (kind) {
    ConnectionFailureKind.invalidCredentials =>
      '{service} rejected these credentials.',
    ConnectionFailureKind.forbidden =>
      'Your account is not allowed to perform this action.',
    ConnectionFailureKind.timeout => '{service} took too long to respond.',
    ConnectionFailureKind.domainNotFound =>
      'The server domain could not be found.',
    ConnectionFailureKind.tls =>
      'The secure connection certificate is invalid.',
    ConnectionFailureKind.unreachable =>
      '{service} is unreachable. Check the domain, port, and network.',
    ConnectionFailureKind.invalidServer =>
      'This address does not appear to be a {service} server.',
    ConnectionFailureKind.server => 'The server returned an internal error.',
    ConnectionFailureKind.invalidResponse =>
      'The server returned an invalid response.',
  };

  Map<String, Object> get messageArguments => {'service': serviceName};

  @override
  String toString() => '$code: $messageKey';
}

class SeerrConnectionPreparation {
  const SeerrConnectionPreparation({
    required this.userId,
    required this.sessionCookie,
    required this.mediaServerType,
    this.discoveredMediaServer,
    this.discoverySource,
    this.mediaServerAccessToken,
    this.mediaServerId,
  });

  final int userId;
  final String sessionCookie;
  final MediaServerType mediaServerType;
  final ServerAddress? discoveredMediaServer;
  final MediaServerDiscoverySource? discoverySource;
  final String? mediaServerAccessToken;
  final String? mediaServerId;
}

class ServiceConnector {
  const ServiceConnector();

  static const requestTimeout = Duration(seconds: 6);

  Future<SeerrConnectionPreparation> prepareSeerr({
    required Uri seerrBaseUrl,
    required SeerrLoginMethod method,
    required String login,
    required String password,
    required String profileId,
    Future<String> Function(PlexPin pin)? authorizePlex,
    void Function(SeerrPreparationStage stage)? onStageChanged,
  }) async {
    final client = SeerrClient(baseUrl: seerrBaseUrl.toString());
    MediaServerType? mediaServerType;
    try {
      onStageChanged?.call(SeerrPreparationStage.checkingServer);
      final settings = await client.publicSettings().timeout(requestTimeout);
      mediaServerType = MediaServerType.fromSeerrValue(
        settings.mediaServerType,
      );
      if (mediaServerType == null) {
        throw const ServiceConnectionException(
          service: ConnectedService.seerr,
          kind: ConnectionFailureKind.invalidServer,
        );
      }

      String? plexToken;
      if (mediaServerType == MediaServerType.plex &&
          method == SeerrLoginMethod.mediaServer) {
        plexToken = await _authorizePlex(
          profileId,
          authorizePlex,
          onStageChanged,
        );
      }

      onStageChanged?.call(SeerrPreparationStage.signingIn);
      final user = switch ((mediaServerType, method)) {
        (MediaServerType.plex, SeerrLoginMethod.mediaServer) =>
          await client.loginPlex(authToken: plexToken!).timeout(requestTimeout),
        (_, SeerrLoginMethod.local) =>
          await client
              .loginLocal(email: login, password: password)
              .timeout(requestTimeout),
        _ =>
          await client
              .loginMediaServer(
                username: login,
                password: password,
                serverType: mediaServerType.seerrValue,
              )
              .timeout(requestTimeout),
      };
      final cookie = client.sessionCookie;
      if (cookie == null || cookie.isEmpty) {
        throw const ServiceConnectionException(
          service: ConnectedService.seerr,
          kind: ConnectionFailureKind.invalidResponse,
        );
      }

      onStageChanged?.call(SeerrPreparationStage.discoveringMediaServer);
      final mediaUrls = await client.availableMediaUrls().timeout(
        requestTimeout,
      );
      if (mediaServerType == MediaServerType.plex) {
        // Seerr can identify the Plex server in media links, but it must never
        // expose a user's Plex token. Link the user's Plex account separately,
        // then match the advertised machine identifier to their resources.
        plexToken ??= await _authorizePlex(
          profileId,
          authorizePlex,
          onStageChanged,
        );
        final authentication = PlexAuthentication(clientIdentifier: profileId);
        final List<PlexResource> resources;
        try {
          resources = await authentication
              .resources(plexToken)
              .timeout(requestTimeout);
        } catch (error) {
          throw classifyError(
            error,
            ConnectedService.mediaServer,
            mediaServerType: MediaServerType.plex,
          );
        }
        final expectedMachineId = _plexMachineId(mediaUrls);
        final resource =
            resources
                .where(
                  (resource) =>
                      expectedMachineId != null &&
                      resource.clientIdentifier == expectedMachineId,
                )
                .firstOrNull ??
            resources.firstOrNull;
        final connection = resource?.preferredConnection;
        if (resource == null || connection == null) {
          throw ServiceConnectionException(
            service: ConnectedService.mediaServer,
            mediaServerType: mediaServerType,
            kind: ConnectionFailureKind.unreachable,
          );
        }
        return SeerrConnectionPreparation(
          userId: user.id,
          sessionCookie: cookie,
          mediaServerType: mediaServerType,
          discoveredMediaServer: ServerAddress.fromUri(connection.uri),
          discoverySource: MediaServerDiscoverySource.plexResources,
          mediaServerAccessToken: plexToken,
          mediaServerId: resource.clientIdentifier,
        );
      }

      // Jellyfin and Emby share the MediaBrowser authentication contract.
      // Prefer Seerr's configured external host, then fall back to a URL found
      // in an available title when public settings hide the server address.
      var discovered = _parseDiscoveredServer(settings.jellyfinExternalHost);
      var discoverySource = discovered == null
          ? null
          : MediaServerDiscoverySource.publicSettings;
      if (discovered == null) {
        discovered = _parseAvailableMediaUrls(mediaUrls);
        if (discovered != null) {
          discoverySource = MediaServerDiscoverySource.availableMedia;
        }
      }
      return SeerrConnectionPreparation(
        userId: user.id,
        sessionCookie: cookie,
        mediaServerType: mediaServerType,
        discoveredMediaServer: discovered,
        discoverySource: discoverySource,
      );
    } catch (error) {
      throw classifyError(
        error,
        ConnectedService.seerr,
        mediaServerType: mediaServerType,
      );
    }
  }

  Future<ProfileCredentials> connectMediaServer({
    required String profileId,
    required Uri mediaServerBaseUrl,
    required String login,
    required String password,
    required SeerrConnectionPreparation seerr,
  }) async {
    if (seerr.mediaServerType == MediaServerType.plex) {
      final token = seerr.mediaServerAccessToken;
      final serverId = seerr.mediaServerId;
      if (token == null || serverId == null) {
        throw const ServiceConnectionException(
          service: ConnectedService.mediaServer,
          mediaServerType: MediaServerType.plex,
          kind: ConnectionFailureKind.invalidResponse,
        );
      }
      return ProfileCredentials(
        seerrSessionCookie: seerr.sessionCookie,
        seerrUserId: seerr.userId,
        mediaServerAccessToken: token,
        mediaServerUserId: '',
        mediaServerServerId: serverId,
      );
    }

    final client = seerr.mediaServerType == MediaServerType.emby
        ? EmbyClient(baseUrl: mediaServerBaseUrl, deviceId: profileId)
        : JellyfinClient(baseUrl: mediaServerBaseUrl, deviceId: profileId);
    try {
      final session = await client
          .authenticateByName(username: login, password: password)
          .timeout(requestTimeout);
      return ProfileCredentials(
        seerrSessionCookie: seerr.sessionCookie,
        seerrUserId: seerr.userId,
        mediaServerAccessToken: session.accessToken,
        mediaServerUserId: session.user.id,
        mediaServerServerId: session.serverId ?? session.user.serverId ?? '',
      );
    } catch (error) {
      throw classifyError(
        error,
        ConnectedService.mediaServer,
        mediaServerType: seerr.mediaServerType,
      );
    }
  }

  Future<String> _authorizePlex(
    String profileId,
    Future<String> Function(PlexPin pin)? authorizePlex,
    void Function(SeerrPreparationStage stage)? onStageChanged,
  ) async {
    try {
      if (authorizePlex == null) {
        throw const ServiceConnectionException(
          service: ConnectedService.mediaServer,
          mediaServerType: MediaServerType.plex,
          kind: ConnectionFailureKind.invalidCredentials,
        );
      }
      onStageChanged?.call(SeerrPreparationStage.signingInToPlex);
      final authentication = PlexAuthentication(clientIdentifier: profileId);
      final pin = await authentication.createPin().timeout(requestTimeout);
      return authorizePlex(pin);
    } catch (error) {
      throw classifyError(
        error,
        ConnectedService.mediaServer,
        mediaServerType: MediaServerType.plex,
      );
    }
  }

  static ServiceConnectionException classifyError(
    Object error,
    ConnectedService service, {
    MediaServerType? mediaServerType,
  }) {
    if (error is ServiceConnectionException) return error;
    ServiceConnectionException result(
      ConnectionFailureKind kind, [
      int? status,
    ]) {
      return ServiceConnectionException(
        service: service,
        mediaServerType: mediaServerType,
        kind: kind,
        statusCode: status,
      );
    }

    if (error is TimeoutException) {
      return result(ConnectionFailureKind.timeout);
    }
    if (error is FormatException) {
      return result(ConnectionFailureKind.invalidResponse);
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      final underlying = error.error;
      if (status == 401) {
        return result(ConnectionFailureKind.invalidCredentials, status);
      }
      if (status == 403) {
        return result(ConnectionFailureKind.forbidden, status);
      }
      if (status == 404) {
        return result(ConnectionFailureKind.invalidServer, status);
      }
      if (status != null && status >= 500) {
        return result(ConnectionFailureKind.server, status);
      }
      if (error.type == DioExceptionType.badCertificate) {
        return result(ConnectionFailureKind.tls);
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return result(ConnectionFailureKind.timeout);
      }
      if (underlying is SocketException &&
          (underlying.osError?.errorCode == 8 ||
              underlying.message.toLowerCase().contains(
                'failed host lookup',
              ))) {
        return result(ConnectionFailureKind.domainNotFound);
      }
      if (error.type == DioExceptionType.connectionError) {
        return result(ConnectionFailureKind.unreachable);
      }
    }
    return result(ConnectionFailureKind.invalidResponse);
  }

  static String friendlyError(Object error) {
    if (error is ServiceConnectionException) return error.messageKey;
    return error.toString().replaceFirst('FormatException: ', '');
  }

  static ServerAddress? _parseDiscoveredServer(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return ServerAddress.parse(input: value, fallbackScheme: 'https');
    } on FormatException {
      return null;
    }
  }

  static ServerAddress? _parseAvailableMediaUrls(List<Uri> values) {
    for (final uri in values) {
      final webIndex = uri.path.indexOf('/web/');
      final basePath = webIndex < 0 ? '' : uri.path.substring(0, webIndex);
      try {
        return ServerAddress.fromUri(
          uri.replace(path: basePath, query: null, fragment: null),
        );
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static String? _plexMachineId(List<Uri> values) {
    for (final uri in values) {
      final source = Uri.decodeComponent('${uri.path}#${uri.fragment}');
      final match = RegExp(r'/server/([^/]+)').firstMatch(source);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
