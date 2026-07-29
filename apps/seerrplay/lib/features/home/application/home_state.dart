import 'dart:async';

import 'package:dio/dio.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

class HomeContent {
  const HomeContent({
    required this.continueWatching,
    required this.trending,
    required this.popularMovies,
    required this.popularSeries,
    required this.categories,
    required this.providers,
    required this.providerRegion,
    required this.isMediaServerReachable,
    required this.isSeerrReachable,
    required this.serviceIssues,
  });

  final List<MediaViewModel> continueWatching;
  final List<MediaViewModel> trending;
  final List<MediaViewModel> popularMovies;
  final List<MediaViewModel> popularSeries;
  final List<HomeCategory> categories;
  final List<HomeProvider> providers;
  final String providerRegion;
  final bool isMediaServerReachable;
  final bool isSeerrReachable;
  final List<HomeServiceIssue> serviceIssues;
}

enum HomeService {
  mediaServer('MEDIA'),
  seerr('SEERR');

  const HomeService(this.code);

  final String code;
}

enum HomeServiceIssueKind {
  unauthorized,
  forbidden,
  timeout,
  unreachable,
  server,
  unknown,
}

class HomeServiceIssue {
  const HomeServiceIssue({
    required this.service,
    required this.kind,
    this.statusCode,
  });

  factory HomeServiceIssue.fromError(HomeService service, Object error) {
    if (error is TimeoutException) {
      return HomeServiceIssue(
        service: service,
        kind: HomeServiceIssueKind.timeout,
      );
    }
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return HomeServiceIssue(
          service: service,
          kind: HomeServiceIssueKind.unauthorized,
          statusCode: statusCode,
        );
      }
      if (statusCode == 403) {
        return HomeServiceIssue(
          service: service,
          kind: HomeServiceIssueKind.forbidden,
          statusCode: statusCode,
        );
      }
      if (statusCode != null && statusCode >= 500) {
        return HomeServiceIssue(
          service: service,
          kind: HomeServiceIssueKind.server,
          statusCode: statusCode,
        );
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return HomeServiceIssue(
          service: service,
          kind: HomeServiceIssueKind.timeout,
        );
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.badCertificate ||
          (error.type == DioExceptionType.unknown && statusCode == null)) {
        return HomeServiceIssue(
          service: service,
          kind: HomeServiceIssueKind.unreachable,
        );
      }
      if (statusCode != null) {
        return HomeServiceIssue(
          service: service,
          kind: HomeServiceIssueKind.server,
          statusCode: statusCode,
        );
      }
    }
    return HomeServiceIssue(
      service: service,
      kind: HomeServiceIssueKind.unknown,
    );
  }

  final HomeService service;
  final HomeServiceIssueKind kind;
  final int? statusCode;

  String get code {
    final suffix = switch (kind) {
      HomeServiceIssueKind.unauthorized => '401',
      HomeServiceIssueKind.forbidden => '403',
      HomeServiceIssueKind.timeout => 'TIMEOUT',
      HomeServiceIssueKind.unreachable => 'NET',
      HomeServiceIssueKind.server => statusCode?.toString() ?? 'SERVER',
      HomeServiceIssueKind.unknown => 'UNKNOWN',
    };
    return 'SV-${service.code}-$suffix';
  }
}

class HomeCategory {
  const HomeCategory({
    required this.id,
    required this.name,
    required this.type,
    this.imageUrl,
  });

  final int id;
  final String name;
  final SeerrMediaType type;
  final Uri? imageUrl;
}

class HomeProvider {
  const HomeProvider({
    required this.id,
    required this.name,
    required this.logoUrl,
  });

  final int id;
  final String name;
  final Uri? logoUrl;
}
