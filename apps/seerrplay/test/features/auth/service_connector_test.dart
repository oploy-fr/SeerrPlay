import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/auth/application/service_connector.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

void main() {
  group('ServiceConnector error classification', () {
    test('distinguishes invalid Seerr credentials', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/auth/local'),
        response: Response<void>(
          requestOptions: RequestOptions(path: '/auth/local'),
          statusCode: 401,
        ),
      );

      final classified = ServiceConnector.classifyError(
        error,
        ConnectedService.seerr,
      );

      expect(classified.kind, ConnectionFailureKind.invalidCredentials);
      expect(classified.code, 'SV-SEERR-AUTH');
    });

    test('distinguishes a missing domain', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/settings/public'),
        type: DioExceptionType.connectionError,
        error: const SocketException('Failed host lookup'),
      );

      final classified = ServiceConnector.classifyError(
        error,
        ConnectedService.seerr,
      );

      expect(classified.kind, ConnectionFailureKind.domainNotFound);
      expect(classified.code, 'SV-SEERR-DNS');
    });

    test('distinguishes a Jellyfin timeout', () {
      final classified = ServiceConnector.classifyError(
        TimeoutException('timeout'),
        ConnectedService.mediaServer,
        mediaServerType: MediaServerType.jellyfin,
      );

      expect(classified.kind, ConnectionFailureKind.timeout);
      expect(classified.code, 'SV-JELLYFIN-TIMEOUT');
    });
  });
}
