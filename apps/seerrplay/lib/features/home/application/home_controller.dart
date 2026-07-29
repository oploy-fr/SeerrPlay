import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/home/application/home_state.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

final homeContentProvider = FutureProvider<HomeContent>((ref) async {
  final mediaServer = ref.watch(mediaServerClientProvider);
  final seerr = ref.watch(seerrClientProvider);
  final language =
      ref.watch(localeControllerProvider).value?.languageCode ?? 'en';
  final seerrUserId = ref
      .watch(appSessionControllerProvider)
      .requireValue
      .credentials!
      .seerrUserId;
  var isMediaServerReachable = false;
  var isSeerrReachable = false;
  HomeServiceIssue? mediaServerIssue;
  HomeServiceIssue? seerrIssue;
  void recordIssue(HomeService service, Object error) {
    final next = HomeServiceIssue.fromError(service, error);
    switch (service) {
      case HomeService.mediaServer:
        mediaServerIssue = _preferredIssue(mediaServerIssue, next);
      case HomeService.seerr:
        seerrIssue = _preferredIssue(seerrIssue, next);
    }
  }

  final mediaPagesFuture = (
    _recoverHomeSection(
      'Media server resume items',
      mediaServer.getResumeItems(),
      _emptyMediaServerPage,
      onSuccess: () => isMediaServerReachable = true,
      onError: (error) => recordIssue(HomeService.mediaServer, error),
    ),
    _recoverHomeSection(
      'Media server next-up items',
      mediaServer.getNextUp(),
      _emptyMediaServerPage,
      onSuccess: () => isMediaServerReachable = true,
      onError: (error) => recordIssue(HomeService.mediaServer, error),
    ),
    _recoverHomeSection(
      'Media server recently played episodes',
      mediaServer.getRecentlyPlayedEpisodes(),
      _emptyMediaServerPage,
      onSuccess: () => isMediaServerReachable = true,
      onError: (error) => recordIssue(HomeService.mediaServer, error),
    ),
  ).wait;
  final discoveryPagesFuture = (
    _recoverHomeSection(
      'Seerr trending',
      seerr.trending(language: language),
      _emptySeerrMediaPage,
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr popular movies page 1',
      seerr.discoverMovies(page: 1),
      _emptySeerrMediaPage,
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr popular movies page 2',
      seerr.discoverMovies(page: 2),
      _emptySeerrMediaPage,
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr popular series page 1',
      seerr.discoverTv(page: 1),
      _emptySeerrMediaPage,
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr popular series page 2',
      seerr.discoverTv(page: 2),
      _emptySeerrMediaPage,
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
  ).wait;
  final configurationFuture = (
    _recoverHomeSection(
      'Seerr movie genres',
      seerr.movieGenres(language: language),
      const <SeerrGenre>[],
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr TV genres',
      seerr.tvGenres(language: language),
      const <SeerrGenre>[],
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr public settings',
      seerr.publicSettings(),
      const SeerrMainSettings(),
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr user settings',
      seerr.userSettings(seerrUserId),
      const SeerrUserSettings(),
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr current user',
      seerr.me(),
      SeerrUser(id: seerrUserId, email: ''),
      onSuccess: () => isSeerrReachable = true,
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
  ).wait;
  final (mediaPages, discoveryPages, configuration) = await (
    mediaPagesFuture,
    discoveryPagesFuture,
    configurationFuture,
  ).wait;
  final (resumePage, nextUpPage, recentlyPlayedPage) = mediaPages;
  final (trendingPage, moviePage1, moviePage2, seriesPage1, seriesPage2) =
      discoveryPages;
  final (movieGenres, tvGenres, mainSettings, userSettings, seerrUser) =
      configuration;
  final providerRegion = userSettings.streamingRegion == 'all'
      ? 'FR'
      : userSettings.streamingRegion ??
            mainSettings.streamingRegion ??
            mainSettings.discoverRegion ??
            'FR';
  final (movieProviders, tvProviders) = await (
    _recoverHomeSection(
      'Seerr movie providers',
      seerr.movieWatchProviders(providerRegion),
      const <SeerrWatchProvider>[],
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr TV providers',
      seerr.tvWatchProviders(providerRegion),
      const <SeerrWatchProvider>[],
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
  ).wait;
  final providerMap = <int, SeerrWatchProvider>{
    for (final provider in [...movieProviders, ...tvProviders])
      provider.id: provider,
  };
  final providers = providerMap.values.toList()
    ..sort((a, b) => a.displayPriority.compareTo(b.displayPriority));
  final (popularMovies, popularSeries) = await (
    _recoverHomeSection(
      'Seerr dashboard movies',
      _loadDashboardTitles(
        initialPages: [moviePage1, moviePage2],
        fetchPage: (page) => seerr.discoverMovies(page: page),
        settings: mainSettings,
        userPermissions: seerrUser.permissions,
      ),
      const <MediaViewModel>[],
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
    _recoverHomeSection(
      'Seerr dashboard series',
      _loadDashboardTitles(
        initialPages: [seriesPage1, seriesPage2],
        fetchPage: (page) => seerr.discoverTv(page: page),
        settings: mainSettings,
        userPermissions: seerrUser.permissions,
      ),
      const <MediaViewModel>[],
      onError: (error) => recordIssue(HomeService.seerr, error),
    ),
  ).wait;
  final categoryMedia = <SeerrMedia>[
    ...trendingPage.results,
    ...moviePage1.results,
    ...moviePage2.results,
    ...seriesPage1.results,
    ...seriesPage2.results,
  ];
  Uri? categoryImage(int genreId, SeerrMediaType type) {
    for (final media in categoryMedia) {
      if (media.type == type &&
          media.genreIds.contains(genreId) &&
          media.backdropPath != null) {
        return _tmdbImage(media.backdropPath, 'w780');
      }
    }
    return null;
  }

  return HomeContent(
    continueWatching: mergeContinueWatchingItems(
      resumeItems: resumePage.items,
      nextUpItems: nextUpPage.items,
      recentlyPlayedEpisodes: recentlyPlayedPage.items,
    ).map((item) => mediaFromServer(item, mediaServer)).toList(growable: false),
    trending: trendingPage.results
        .where((media) => media.type != SeerrMediaType.person)
        .map(mediaFromSeerr)
        .toList(growable: false),
    popularMovies: popularMovies,
    popularSeries: popularSeries,
    categories: [
      for (final genre in movieGenres)
        HomeCategory(
          id: genre.id,
          name: genre.name,
          type: SeerrMediaType.movie,
          imageUrl: categoryImage(genre.id, SeerrMediaType.movie),
        ),
      for (final genre in tvGenres)
        if (!movieGenres.any((item) => item.name == genre.name))
          HomeCategory(
            id: genre.id,
            name: genre.name,
            type: SeerrMediaType.tv,
            imageUrl: categoryImage(genre.id, SeerrMediaType.tv),
          ),
    ],
    providers: providers
        .take(18)
        .map(
          (provider) => HomeProvider(
            id: provider.id,
            name: provider.name,
            logoUrl: _tmdbImage(provider.logoPath, 'w185'),
          ),
        )
        .toList(growable: false),
    providerRegion: providerRegion,
    isMediaServerReachable: isMediaServerReachable,
    isSeerrReachable: isSeerrReachable,
    serviceIssues: [
      if (mediaServerIssue != null) mediaServerIssue!,
      if (seerrIssue != null) seerrIssue!,
    ],
  );
});

HomeServiceIssue _preferredIssue(
  HomeServiceIssue? current,
  HomeServiceIssue next,
) {
  if (current == null) return next;
  int priority(HomeServiceIssueKind kind) => switch (kind) {
    HomeServiceIssueKind.unauthorized => 6,
    HomeServiceIssueKind.forbidden => 5,
    HomeServiceIssueKind.unreachable => 4,
    HomeServiceIssueKind.timeout => 3,
    HomeServiceIssueKind.server => 2,
    HomeServiceIssueKind.unknown => 1,
  };
  return priority(next.kind) > priority(current.kind) ? next : current;
}

const _emptyMediaServerPage = MediaServerItemsPage(
  items: [],
  totalRecordCount: 0,
  startIndex: 0,
);

const _emptySeerrMediaPage = SeerrPage<SeerrMedia>(
  page: 1,
  totalPages: 1,
  totalResults: 0,
  results: [],
);

Future<T> _recoverHomeSection<T>(
  String section,
  Future<T> request,
  T fallback, {
  void Function()? onSuccess,
  void Function(Object error)? onError,
}) async {
  try {
    final value = await request.timeout(const Duration(seconds: 20));
    onSuccess?.call();
    return value;
  } catch (error, stackTrace) {
    onError?.call(error);
    developer.log(
      'Unable to load $section',
      name: 'SeerrPlay.Home',
      error: error,
      stackTrace: stackTrace,
    );
    return fallback;
  }
}

List<MediaServerItem> mergeContinueWatchingItems({
  required List<MediaServerItem> resumeItems,
  required List<MediaServerItem> nextUpItems,
  required List<MediaServerItem> recentlyPlayedEpisodes,
}) {
  // A series may appear both as a partially watched episode and as its next
  // episode. Keep the current episode, suppress that duplicate next-up entry,
  // and use the previous episode's timestamp to position untouched successors.
  final latestSeriesPlayback = <String, DateTime>{};
  for (final item in recentlyPlayedEpisodes) {
    final seriesId = item.seriesId;
    final lastPlayedDate = item.userData?.lastPlayedDate;
    if (seriesId == null || lastPlayedDate == null) continue;
    final current = latestSeriesPlayback[seriesId];
    if (current == null || lastPlayedDate.isAfter(current)) {
      latestSeriesPlayback[seriesId] = lastPlayedDate;
    }
  }

  final resumedSeries = {
    for (final item in resumeItems)
      if (item.seriesId != null) item.seriesId!,
  };
  final seenItemIds = <String>{};
  final rankedItems = <_RankedMediaServerItem>[];
  var stableIndex = 0;

  for (final item in resumeItems) {
    if (!seenItemIds.add(item.id)) continue;
    rankedItems.add(
      _RankedMediaServerItem(
        item: item,
        lastPlayedDate:
            item.userData?.lastPlayedDate ??
            (item.seriesId == null
                ? null
                : latestSeriesPlayback[item.seriesId!]),
        stableIndex: stableIndex++,
      ),
    );
  }

  for (final item in nextUpItems) {
    if (!seenItemIds.add(item.id)) continue;
    if (item.seriesId != null && resumedSeries.contains(item.seriesId)) {
      continue;
    }
    rankedItems.add(
      _RankedMediaServerItem(
        item: item,
        lastPlayedDate: item.seriesId == null
            ? item.userData?.lastPlayedDate
            : latestSeriesPlayback[item.seriesId!],
        stableIndex: stableIndex++,
      ),
    );
  }

  rankedItems.sort((left, right) {
    final leftDate = left.lastPlayedDate;
    final rightDate = right.lastPlayedDate;
    if (leftDate != null && rightDate != null) {
      final comparison = rightDate.compareTo(leftDate);
      if (comparison != 0) return comparison;
    } else if (leftDate != null) {
      return -1;
    } else if (rightDate != null) {
      return 1;
    }
    return left.stableIndex.compareTo(right.stableIndex);
  });

  return rankedItems.map((ranked) => ranked.item).toList(growable: false);
}

class _RankedMediaServerItem {
  const _RankedMediaServerItem({
    required this.item,
    required this.lastPlayedDate,
    required this.stableIndex,
  });

  final MediaServerItem item;
  final DateTime? lastPlayedDate;
  final int stableIndex;
}

final userRequestsProvider = FutureProvider<List<MediaViewModel>>((ref) async {
  final session = ref.watch(appSessionControllerProvider).requireValue;
  final client = ref.watch(seerrClientProvider);
  final mediaServer = ref.watch(mediaServerClientProvider);
  final language =
      ref.watch(localeControllerProvider).value?.languageCode ?? 'en';
  final values = await Future.wait<Object>([
    client.userRequests(session.credentials!.seerrUserId, take: 100),
    mediaServer.getResumeItems(limit: 200),
  ]);
  final page = values[0] as SeerrUserRequests;
  final resumeItems = (values[1] as MediaServerItemsPage).items;
  final startedIds = <String>{
    for (final item in resumeItems) item.id,
    for (final item in resumeItems)
      if (item.seriesId != null) item.seriesId!,
  };
  final items = await Future.wait(
    page.results.map((request) async {
      final info = request.media;
      if (info == null) return null;
      final mediaServerId = info.mediaServerItemId;
      if (mediaServerId != null) {
        if (startedIds.contains(mediaServerId)) return null;
        var started = false;
        try {
          started = await mediaServer.hasStartedItem(mediaServerId);
        } catch (_) {
          started = false;
        }
        if (started) return null;
      }
      try {
        final details = request.type == SeerrMediaType.movie
            ? await client.movieDetails(info.tmdbId, language: language)
            : await client.tvDetails(info.tmdbId, language: language);
        return mediaFromRequest(request, details);
      } catch (_) {
        return null;
      }
    }),
  );
  final timer = Timer(const Duration(seconds: 15), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return items.whereType<MediaViewModel>().toList(growable: false);
});

final availableUnwatchedRequestsProvider =
    Provider<AsyncValue<List<MediaViewModel>>>(
      (ref) => ref
          .watch(userRequestsProvider)
          .whenData(
            (items) => items
                .where(
                  (media) =>
                      media.lifecycleStatus == MediaLifecycleStatus.available,
                )
                .toList(growable: false),
          ),
    );

final providerResultsProvider = FutureProvider.autoDispose
    .family<List<MediaViewModel>, (int, String)>((ref, provider) async {
      final client = ref.watch(seerrClientProvider);
      final pages = await Future.wait([
        client.discoverMovies(
          page: 1,
          watchRegion: provider.$2,
          watchProviderId: provider.$1,
        ),
        client.discoverMovies(
          page: 2,
          watchRegion: provider.$2,
          watchProviderId: provider.$1,
        ),
        client.discoverTv(
          page: 1,
          watchRegion: provider.$2,
          watchProviderId: provider.$1,
        ),
        client.discoverTv(
          page: 2,
          watchRegion: provider.$2,
          watchProviderId: provider.$1,
        ),
      ]);
      final seen = <String>{};
      return [
            ...pages[0].results,
            ...pages[1].results,
            ...pages[2].results,
            ...pages[3].results,
          ]
          .where((media) => seen.add('${media.type.apiValue}:${media.id}'))
          .map(mediaFromSeerr)
          .toList(growable: false);
    });

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<MediaViewModel>, String>((ref, query) async {
      final normalizedQuery = query.trim();
      if (normalizedQuery.isEmpty) return const [];
      final client = ref.watch(seerrClientProvider);
      final language =
          ref.watch(localeControllerProvider).value?.languageCode ?? 'en';
      final cancelToken = CancelToken();
      ref.onDispose(cancelToken.cancel);
      final page = await client
          .search(
            query: normalizedQuery,
            language: language,
            cancelToken: cancelToken,
          )
          .timeout(const Duration(seconds: 12));
      final mediaResults = page.results
          .where((media) => media.type != SeerrMediaType.person)
          .toList(growable: false);
      return mediaResults.map(mediaFromSeerr).toList(growable: false);
    });

final categoryResultsProvider = FutureProvider.autoDispose
    .family<List<MediaViewModel>, (int, SeerrMediaType)>((ref, category) async {
      final client = ref.watch(seerrClientProvider);
      final page = category.$2 == SeerrMediaType.movie
          ? await client.discoverMovies(genreId: category.$1)
          : await client.discoverTv(genreId: category.$1);
      return page.results.map(mediaFromSeerr).toList(growable: false);
    });

MediaViewModel mediaFromServer(MediaServerItem item, MediaServerClient client) {
  final isEpisode = item.type == 'Episode';
  final tmdbValue = item.providerIds.entries
      .where((entry) => entry.key.toLowerCase() == 'tmdb')
      .map((entry) => entry.value)
      .firstOrNull;
  final runtime = item.runTimeTicks;
  final position = item.userData?.playbackPositionTicks;
  final progress =
      runtime != null && runtime > 0 && position != null && position > 0
      ? position / runtime
      : null;
  final episode = isEpisode
      ? [
          if (item.parentIndexNumber != null) 'S${item.parentIndexNumber}',
          if (item.indexNumber != null) 'E${item.indexNumber}',
        ].join('')
      : null;
  final primaryImage = client.imageUri(
    item.id,
    tag: item.primaryImagePath ?? item.primaryImageTag,
    maxWidth: isEpisode ? 960 : 500,
  );
  final backdropImage =
      item.backdropImagePath == null && item.backdropImageTags.isEmpty
      ? null
      : client.imageUri(
          item.id,
          imageType: 'Backdrop',
          tag: item.backdropImagePath ?? item.backdropImageTags.firstOrNull,
          maxWidth: 1280,
        );

  return MediaViewModel(
    id: '${client.serverType.name}:${item.id}',
    title: isEpisode ? (item.seriesName ?? item.name) : item.name,
    subtitle: isEpisode
        ? [
            episode,
            item.name,
          ].where((value) => value?.isNotEmpty == true).join(' · ')
        : item.productionYear?.toString(),
    overview: item.overview,
    kind: switch (item.type) {
      'Movie' => MediaKind.movie,
      'Series' => MediaKind.series,
      'Episode' => MediaKind.episode,
      'Video' => MediaKind.movie,
      _ => MediaKind.unknown,
    },
    posterUrl: primaryImage,
    // Episode primary images are generally frame captures. They are more
    // useful than the generic series backdrop in Continue Watching and detail.
    backdropUrl: isEpisode ? primaryImage : backdropImage,
    tmdbId: int.tryParse(tmdbValue ?? ''),
    mediaServerItemId: item.id,
    isAvailable: true,
    progress: progress,
  );
}

MediaViewModel mediaFromSeerr(SeerrMedia media) {
  final available = media.mediaInfo?.availability;
  final lifecycle = mediaInfoLifecycle(media.mediaInfo);
  return MediaViewModel(
    id: 'seerr:${media.type.apiValue}:${media.id}',
    title: media.title,
    subtitle: media.releaseDate?.year.toString(),
    overview: media.overview,
    kind: media.type == SeerrMediaType.movie
        ? MediaKind.movie
        : MediaKind.series,
    posterUrl: _tmdbImage(media.posterPath, 'w500'),
    backdropUrl: _tmdbImage(media.backdropPath, 'w1280'),
    tmdbId: media.id,
    mediaServerItemId: media.mediaInfo?.mediaServerItemId,
    isAvailable:
        available == SeerrAvailability.available ||
        available == SeerrAvailability.partiallyAvailable,
    lifecycleStatus: lifecycle.$1,
    statusLabel: lifecycle.$2,
    downloadProgress: lifecycle.$3,
  );
}

MediaViewModel mediaFromRequest(
  SeerrMediaRequest request,
  SeerrMediaDetails details,
) {
  final mediaInfo = request.media;
  final status = requestLifecycle(request);
  return MediaViewModel(
    id: 'request:${request.id}',
    title: details.title,
    subtitle: details.releaseDate?.year.toString(),
    overview: details.overview,
    kind: request.type == SeerrMediaType.movie
        ? MediaKind.movie
        : MediaKind.series,
    posterUrl: _tmdbImage(details.posterPath, 'w500'),
    backdropUrl: _tmdbImage(details.backdropPath, 'w1280'),
    tmdbId: details.id,
    mediaServerItemId: mediaInfo?.mediaServerItemId,
    isAvailable:
        status.$1 == MediaLifecycleStatus.available ||
        status.$1 == MediaLifecycleStatus.partiallyAvailable,
    lifecycleStatus: status.$1,
    statusLabel: status.$2,
    downloadProgress: status.$3,
    seerrRequestId: request.id,
  );
}

(MediaLifecycleStatus, String?, double?) mediaInfoLifecycle(
  SeerrMediaInfo? info,
) {
  final downloads = info?.downloadStatus ?? const <SeerrDownloadItem>[];
  if (downloads.isNotEmpty) {
    final progress = downloads
        .map((item) => item.progress)
        .whereType<double>()
        .firstOrNull;
    return (
      MediaLifecycleStatus.downloading,
      progress == null
          ? 'Downloading'
          : 'Download ${(progress * 100).round()} %',
      progress,
    );
  }
  return switch (info?.availability) {
    SeerrAvailability.available => (
      MediaLifecycleStatus.available,
      'Available',
      null,
    ),
    SeerrAvailability.partiallyAvailable => (
      MediaLifecycleStatus.partiallyAvailable,
      'Partially available',
      null,
    ),
    SeerrAvailability.processing => (
      MediaLifecycleStatus.requested,
      'Requested media',
      null,
    ),
    SeerrAvailability.pending => (
      MediaLifecycleStatus.pendingApproval,
      'Pending',
      null,
    ),
    _ => (MediaLifecycleStatus.none, null, null),
  };
}

(MediaLifecycleStatus, String, double?) requestLifecycle(
  SeerrMediaRequest request,
) {
  if (request.status == SeerrRequestStatus.declined) {
    return (MediaLifecycleStatus.declined, 'Declined', null);
  }
  if (request.status == SeerrRequestStatus.failed) {
    return (MediaLifecycleStatus.failed, 'Failed', null);
  }
  if (request.status == SeerrRequestStatus.pendingApproval) {
    return (MediaLifecycleStatus.pendingApproval, 'Pending', null);
  }
  final info = request.media;
  final downloads = info?.downloadStatus ?? const <SeerrDownloadItem>[];
  if (downloads.isNotEmpty) {
    final progress =
        downloads
            .map((item) => item.progress)
            .whereType<double>()
            .firstOrNull ??
        0;
    return (
      MediaLifecycleStatus.downloading,
      'Download ${(progress * 100).round()} %',
      progress,
    );
  }
  return switch (info?.availability) {
    SeerrAvailability.available => (
      MediaLifecycleStatus.available,
      'Available',
      null,
    ),
    SeerrAvailability.partiallyAvailable => (
      MediaLifecycleStatus.partiallyAvailable,
      'Partially available',
      null,
    ),
    SeerrAvailability.processing => (
      MediaLifecycleStatus.requested,
      'Requested media',
      null,
    ),
    SeerrAvailability.pending => (
      MediaLifecycleStatus.requested,
      'Requested media',
      null,
    ),
    _ =>
      request.status == SeerrRequestStatus.completed
          ? (MediaLifecycleStatus.available, 'Available', null)
          : (MediaLifecycleStatus.requested, 'Requested media', null),
  };
}

Future<List<MediaViewModel>> _loadDashboardTitles({
  required List<SeerrPage<SeerrMedia>> initialPages,
  required Future<SeerrPage<SeerrMedia>> Function(int page) fetchPage,
  required SeerrMainSettings settings,
  required int userPermissions,
}) async {
  final items = [for (final page in initialPages) ...page.results];
  final firstPage = initialPages.first;
  var loadedPageCount = initialPages.length;
  var visibleItems = _applyDashboardVisibility(items, settings);

  while (visibleItems.length < 24 &&
      loadedPageCount < 5 &&
      firstPage.totalResults > loadedPageCount * 20 &&
      loadedPageCount < firstPage.totalPages) {
    loadedPageCount++;
    final page = await fetchPage(loadedPageCount);
    items.addAll(page.results);
    visibleItems = _applyDashboardVisibility(items, settings);
  }

  final canViewBlocklist =
      userPermissions & 2 != 0 ||
      userPermissions & 268435456 != 0 ||
      userPermissions & 1073741824 != 0;
  return visibleItems
      .take(20)
      .where(
        (media) =>
            canViewBlocklist ||
            media.mediaInfo?.availability != SeerrAvailability.blocklisted,
      )
      .map(mediaFromSeerr)
      .toList(growable: false);
}

List<SeerrMedia> _applyDashboardVisibility(
  List<SeerrMedia> items,
  SeerrMainSettings settings,
) {
  return items
      .where((media) {
        final status = media.mediaInfo?.availability;
        if (settings.hideAvailable &&
            (status == SeerrAvailability.available ||
                status == SeerrAvailability.partiallyAvailable)) {
          return false;
        }
        if (settings.hideBlocklisted &&
            status == SeerrAvailability.blocklisted) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

Uri? _tmdbImage(String? path, String size) {
  if (path == null || path.isEmpty) return null;
  return Uri.https('image.tmdb.org', '/t/p/$size$path');
}
