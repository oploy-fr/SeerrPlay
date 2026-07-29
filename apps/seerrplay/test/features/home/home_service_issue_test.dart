import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/home/application/home_state.dart';

void main() {
  group('HomeServiceIssue', () {
    test('identifies forbidden Seerr access', () {
      final issue = HomeServiceIssue.fromError(
        HomeService.seerr,
        _responseError(403),
      );

      expect(issue.kind, HomeServiceIssueKind.forbidden);
      expect(issue.code, 'SV-SEERR-403');
    });

    test('identifies an unreachable media server', () {
      final options = RequestOptions(path: '/System/Info');
      final issue = HomeServiceIssue.fromError(
        HomeService.mediaServer,
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
        ),
      );

      expect(issue.kind, HomeServiceIssueKind.unreachable);
      expect(issue.code, 'SV-MEDIA-NET');
    });

    test('identifies a request timeout', () {
      final issue = HomeServiceIssue.fromError(
        HomeService.mediaServer,
        TimeoutException('No response'),
      );

      expect(issue.kind, HomeServiceIssueKind.timeout);
      expect(issue.code, 'SV-MEDIA-TIMEOUT');
    });

    test('preserves a Seerr server status code', () {
      final issue = HomeServiceIssue.fromError(
        HomeService.seerr,
        _responseError(530),
      );

      expect(issue.kind, HomeServiceIssueKind.server);
      expect(issue.code, 'SV-SEERR-530');
    });
  });
}

DioException _responseError(int statusCode) {
  final options = RequestOptions(path: '/api/v1/test');
  return DioException(
    requestOptions: options,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
    ),
    type: DioExceptionType.badResponse,
  );
}
