import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/downloads/application/downloads_controller.dart';
import 'package:seerrplay/features/downloads/domain/offline_download.dart';
import 'package:seerrplay/features/downloads/domain/offline_download_option.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/media/application/media_metadata_resolver.dart';
import 'package:seerrplay/features/media/application/season_content.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_rail.dart';
import 'package:seerrplay/features/media/presentation/person_detail_screen.dart';
import 'package:seerrplay/features/media/presentation/season_detail_screen.dart';
import 'package:seerrplay/features/player/presentation/player_screen.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaDetailScreen extends ConsumerStatefulWidget {
  const MediaDetailScreen({required this.media, super.key});
  final MediaViewModel media;

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  late final Future<_DetailContent> _content = _loadDetails();
  bool _requesting = false;
  bool _requested = false;
  bool _requestDeleted = false;
  bool _refreshingRequest = false;
  bool? _markedWatched;
  EpisodeMetadataContext? _episodeContext;
  int? _activeRequestId;
  Timer? _requestRefreshTimer;
  SeerrMediaRequest? _liveRequest;

  @override
  void initState() {
    super.initState();
    _activeRequestId = widget.media.seerrRequestId;
    if (_activeRequestId != null) {
      _startRequestRefresh();
    }
  }

  @override
  void dispose() {
    _requestRefreshTimer?.cancel();
    super.dispose();
  }

  void _startRequestRefresh() {
    _requestRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshRequest()),
    );
    unawaited(_refreshRequest());
  }

  Future<void> _refreshRequest() async {
    final requestId = _activeRequestId;
    if (requestId == null || _refreshingRequest || _requestDeleted) return;
    _refreshingRequest = true;
    try {
      final request = await ref
          .read(seerrClientProvider)
          .mediaRequest(requestId);
      if (!mounted || requestId != _activeRequestId) return;
      setState(() => _liveRequest = request);
      final availability = request.media?.availability;
      if (request.status == SeerrRequestStatus.declined ||
          request.status == SeerrRequestStatus.failed ||
          request.status == SeerrRequestStatus.completed ||
          availability == SeerrAvailability.available) {
        _requestRefreshTimer?.cancel();
        _requestRefreshTimer = null;
      }
    } on DioException {
      return;
    } finally {
      _refreshingRequest = false;
    }
  }

  Future<_DetailContent> _loadDetails() async {
    var id = widget.media.tmdbId;
    var kind = widget.media.kind;
    EpisodeMetadataContext? episodeContext;
    if (kind == MediaKind.episode) {
      try {
        final mediaServer = ref.read(mediaServerClientProvider);
        final episodeId = widget.media.mediaServerItemId;
        if (episodeId == null) return const _DetailContent();
        episodeContext = await resolveEpisodeMetadata(
          mediaServer: mediaServer,
          episodeId: episodeId,
        );
        _episodeContext = episodeContext;
        id = episodeContext?.seriesTmdbId;
        kind = MediaKind.series;
      } on DioException {
        return const _DetailContent();
      } on FormatException {
        return const _DetailContent();
      }
    }
    if (id == null) {
      return const _DetailContent();
    }
    final client = ref.read(seerrClientProvider);
    final language =
        ref.read(localeControllerProvider).value?.languageCode ?? 'en';
    final type = kind == MediaKind.movie
        ? SeerrMediaType.movie
        : SeerrMediaType.tv;
    final details = type == SeerrMediaType.movie
        ? await client.movieDetails(id, language: language)
        : await client.tvDetails(id, language: language);
    SeerrRatings? ratings;
    try {
      final loadedRatings = await client.ratings(type: type, mediaId: id);
      if (!loadedRatings.isEmpty) ratings = loadedRatings;
    } on DioException {
      ratings = null;
    }
    var recommendations = const <MediaViewModel>[];
    var similar = const <MediaViewModel>[];
    try {
      final page = await client.recommendations(
        type: type,
        mediaId: id,
        language: language,
      );
      recommendations = page.results.map(mediaFromSeerr).toList();
    } on DioException {
      recommendations = const [];
    }
    try {
      final page = await client.similar(
        type: type,
        mediaId: id,
        language: language,
      );
      similar = page.results.map(mediaFromSeerr).toList();
    } on DioException {
      similar = const [];
    }
    return _DetailContent(
      details: details,
      ratings: ratings,
      recommendations: recommendations,
      similar: similar,
      episodeContext: episodeContext,
    );
  }

  Future<void> _request() async {
    final id = widget.media.tmdbId;
    if (id == null) return;
    setState(() => _requesting = true);
    try {
      final client = ref.read(seerrClientProvider);
      final request = widget.media.kind == MediaKind.movie
          ? await client.requestMovie(id)
          : await client.requestTvAllSeasons(id);
      if (!mounted) return;
      setState(() {
        _requested = true;
        _activeRequestId = request.id;
        _liveRequest = request;
      });
      _startRequestRefresh();
      ref.invalidate(userRequestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Request sent to Seerr.'))),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.response?.statusCode == 409
                ? context.tr('This media has already been requested.')
                : context.tr('Unable to send the request.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _retry() async {
    final requestId = _activeRequestId ?? widget.media.seerrRequestId;
    if (requestId == null) return;
    setState(() => _requesting = true);
    try {
      final request = await ref
          .read(seerrClientProvider)
          .retryRequest(requestId);
      if (!mounted) return;
      setState(() {
        _requested = true;
        _liveRequest = request;
      });
      _startRequestRefresh();
      ref.invalidate(userRequestsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('New attempt sent.'))));
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Unable to retry the request.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _deleteRequest(MediaViewModel media) async {
    final requestId = media.seerrRequestId;
    if (requestId == null ||
        media.lifecycleStatus != MediaLifecycleStatus.pendingApproval) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete this request?')),
        content: Text(
          context.tr(
            'The pending request for “{title}” will be removed from Seerr.',
            arguments: {'title': media.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete request')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _requesting = true);
    try {
      await ref.read(seerrClientProvider).deleteRequest(requestId);
      if (!mounted) return;
      setState(() {
        _requestDeleted = true;
        _requested = false;
        _activeRequestId = null;
        _liveRequest = null;
      });
      _requestRefreshTimer?.cancel();
      _requestRefreshTimer = null;
      ref.invalidate(userRequestsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Request deleted.'))));
    } on DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Unable to delete the request.'))),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _play(
    SeerrMediaDetails? details, {
    OfflineDownload? offlineDownload,
    bool fromBeginning = false,
  }) async {
    final playable = widget.media.copyWith(
      mediaServerItemId: widget.media.kind == MediaKind.episode
          ? widget.media.mediaServerItemId
          : details?.mediaInfo?.mediaServerItemId,
      isAvailable: true,
    );
    final mediaServerItemId = playable.mediaServerItemId;
    final localFile = offlineDownload?.status == OfflineDownloadStatus.completed
        ? await ref
              .read(downloadsControllerProvider.notifier)
              .localFileForItem(offlineDownload!.downloadedItemId)
        : mediaServerItemId == null
        ? null
        : await ref
              .read(downloadsControllerProvider.notifier)
              .localFileForItem(mediaServerItemId);
    if (!mounted) return;
    final playbackMedia = localFile == null
        ? playable
        : playable.copyWith(localFilePath: localFile.path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          media: playbackMedia,
          startFromBeginning: fromBeginning,
        ),
      ),
    );
  }

  Future<void> _setWatched(bool watched) async {
    final itemId = widget.media.mediaServerItemId;
    if (itemId == null || itemId.isEmpty) return;
    try {
      await ref
          .read(mediaServerClientProvider)
          .setItemPlayed(itemId, played: watched);
      if (!mounted) return;
      setState(() => _markedWatched = watched);
      ref.invalidate(homeContentProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(watched ? 'Marked as watched.' : 'Marked as unwatched.'),
          ),
        ),
      );
      if (watched) await _openNextUnwatchedEpisode();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Unable to update watched status.'))),
      );
    }
  }

  Future<void> _openNextUnwatchedEpisode() async {
    final episodeContext = _episodeContext;
    final currentItemId = widget.media.mediaServerItemId;
    if (episodeContext == null || currentItemId == null) return;
    final mediaServer = ref.read(mediaServerClientProvider);
    try {
      final episodes = await mediaServer.getSeriesEpisodes(
        episodeContext.seriesId,
      );
      final next = nextUnwatchedEpisode(
        episodes,
        currentEpisodeId: currentItemId,
      );
      if (!mounted) return;
      if (next == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('No unwatched episode remains.'))),
        );
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              MediaDetailScreen(media: mediaFromServer(next, mediaServer)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Unable to load the next episode.'))),
      );
    }
  }

  void _openEpisode(SeasonEpisodeState episode) {
    final item = episode.mediaServerItem;
    if (item == null) return;
    if (item.id == widget.media.mediaServerItemId) return;
    final mediaServer = ref.read(mediaServerClientProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MediaDetailScreen(media: mediaFromServer(item, mediaServer)),
      ),
    );
  }

  void _open(MediaViewModel media) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MediaDetailScreen(media: media)),
    );
  }

  Future<void> _download(MediaViewModel media) async {
    try {
      final controller = ref.read(downloadsControllerProvider.notifier);
      final preparation = await controller.prepareDownload(media);
      if (!mounted) return;
      final option = await showModalBottomSheet<OfflineDownloadOption>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _DownloadOptionsSheet(preparation: preparation),
      );
      if (option == null || !mounted) return;
      await controller.download(media, preparation, option);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Download started.'))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Unable to start the download.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveRequests = ref.watch(userRequestsProvider);
    final liveMedia =
        widget.media.tmdbId == null || widget.media.kind == MediaKind.episode
        ? null
        : liveRequests.value
              ?.where((media) => media.tmdbId == widget.media.tmdbId)
              .firstOrNull;
    var currentMedia = _requestDeleted
        ? widget.media.withoutRequestStatus()
        : liveMedia ?? widget.media;
    final liveRequest = _liveRequest;
    if (!_requestDeleted &&
        liveRequest != null &&
        liveRequest.id == (_activeRequestId ?? currentMedia.seerrRequestId)) {
      final lifecycle = requestLifecycle(liveRequest);
      currentMedia = currentMedia.withRequestStatus(
        lifecycleStatus: lifecycle.$1,
        statusLabel: lifecycle.$2,
        downloadProgress: lifecycle.$3,
        mediaServerItemId: liveRequest.media?.mediaServerItemId,
        isAvailable:
            lifecycle.$1 == MediaLifecycleStatus.available ||
            lifecycle.$1 == MediaLifecycleStatus.partiallyAvailable,
        seerrRequestId: liveRequest.id,
      );
    }
    final offlineDownloads =
        ref.watch(downloadsControllerProvider).value ?? const [];
    return FutureBuilder<_DetailContent>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final content = snapshot.data ?? const _DetailContent();
        final details = content.details;
        final ratings = content.ratings;
        final region = _regionForLocale(Localizations.localeOf(context));
        final availability = details?.mediaInfo?.availability;
        final isAvailable =
            currentMedia.isAvailable ||
            availability == SeerrAvailability.available ||
            availability == SeerrAvailability.partiallyAvailable;
        final inferred = mediaInfoLifecycle(details?.mediaInfo);
        final primaryTrailer = details?.relatedVideos
            .where((video) => video.type?.toLowerCase() == 'trailer')
            .firstOrNull;
        final featuredVideo =
            primaryTrailer ?? details?.relatedVideos.firstOrNull;
        final hasLiveRequestState =
            currentMedia.seerrRequestId != null || liveRequest != null;
        final actionMedia =
            !_requestDeleted &&
                !hasLiveRequestState &&
                inferred.$1 != MediaLifecycleStatus.none
            ? currentMedia.copyWith(
                lifecycleStatus: inferred.$1,
                statusLabel: inferred.$2,
                downloadProgress: inferred.$3,
              )
            : currentMedia;
        final downloadableMedia = actionMedia.copyWith(
          mediaServerItemId: widget.media.kind == MediaKind.episode
              ? actionMedia.mediaServerItemId
              : details?.mediaInfo?.mediaServerItemId ??
                    actionMedia.mediaServerItemId,
        );
        final offlineDownload = offlineDownloads
            .where(
              (download) =>
                  download.sourceItemId == downloadableMedia.mediaServerItemId,
            )
            .firstOrNull;
        final isWatched =
            _markedWatched ??
            content.episodeContext?.episode.userData?.played ??
            false;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                actions: [
                  if (isAvailable &&
                      downloadableMedia.mediaServerItemId?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: _PlaybackOptionsMenu(
                          isWatched: isWatched,
                          showDownload: featuredVideo?.url.isNotEmpty == true,
                          offlineDownload: offlineDownload,
                          onPlayFromBeginning: () => _play(
                            details,
                            offlineDownload: offlineDownload,
                            fromBeginning: true,
                          ),
                          onSetWatched: _setWatched,
                          onDownload: () => _download(downloadableMedia),
                        ),
                      ),
                    ),
                ],
                flexibleSpace: _DetailHero(
                  title: details?.title ?? widget.media.title,
                  imageUrl:
                      widget.media.backdropUrl ??
                      _tmdbImage(details?.backdropPath, 'w1280'),
                  details: details,
                  ratings: ratings,
                  media: actionMedia,
                  region: region,
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PrimaryActions(
                            trailer: featuredVideo,
                            isAvailable: isAvailable,
                            media: downloadableMedia,
                            loading: _requesting,
                            requested: _requested,
                            onPlay: () => _play(
                              details,
                              offlineDownload: offlineDownload,
                            ),
                            onRequest: _request,
                            onRetry: _retry,
                            onDeleteRequest: () =>
                                _deleteRequest(downloadableMedia),
                            onDownload: () => _download(downloadableMedia),
                            offlineDownload: offlineDownload,
                            resume: widget.media.hasPlaybackProgress,
                          ),
                          if (actionMedia.lifecycleStatus ==
                              MediaLifecycleStatus.downloading)
                            _SeerrDownloadProgress(
                              progress: actionMedia.downloadProgress,
                            ),
                          _DetailSection(
                            title: context.tr('Overview'),
                            child: Text(
                              widget.media.kind == MediaKind.episode &&
                                      widget.media.overview?.isNotEmpty == true
                                  ? widget.media.overview!
                                  : details?.overview.isNotEmpty == true
                                  ? details!.overview
                                  : widget.media.overview ??
                                        context.tr('No summary available.'),
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(height: 1.55),
                            ),
                          ),
                          if (details != null) ...[
                            if (details.cast.isNotEmpty)
                              _Cast(cast: details.cast),
                            if (details is SeerrTvDetails &&
                                details.seasons.isNotEmpty)
                              _Seasons(
                                tvId: details.id,
                                seasons: details.seasons,
                                availability:
                                    details.mediaInfo?.seasons ?? const [],
                                mediaServerSeriesId:
                                    content.episodeContext?.seriesId ??
                                    details.mediaInfo?.mediaServerItemId,
                                currentSeasonNumber:
                                    content.episodeContext?.seasonNumber,
                                currentEpisodeNumber:
                                    content.episodeContext?.episodeNumber,
                                currentEpisodeWatched: _markedWatched,
                                onEpisodeSelected: _openEpisode,
                              ),
                            _MoreInformation(details: details, region: region),
                          ],
                          if (content.recommendations.isNotEmpty) ...[
                            const SizedBox(height: 34),
                            MediaRail(
                              title: context.tr('Recommendations'),
                              items: content.recommendations,
                              onSelected: _open,
                            ),
                          ],
                          if (content.similar.isNotEmpty) ...[
                            const SizedBox(height: 30),
                            MediaRail(
                              title: context.tr('Similar titles'),
                              items: content.similar,
                              onSelected: _open,
                            ),
                          ],
                          if (snapshot.hasError) ...[
                            const SizedBox(height: 20),
                            Text(
                              context.tr(
                                'Detailed Seerr information is unavailable.',
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DownloadOptionsSheet extends StatefulWidget {
  const _DownloadOptionsSheet({required this.preparation});

  final OfflineDownloadPreparation preparation;

  @override
  State<_DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<_DownloadOptionsSheet> {
  late OfflineDownloadOption _selected = widget.preparation.options.firstWhere(
    (option) => option.recommended,
    orElse: () => widget.preparation.options.first,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('Choose download quality'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'The size is an estimate. Compatible copies are transcoded by your media server before offline playback.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final option in widget.preparation.options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _DownloadOptionTile(
                          option: option,
                          selected: option.id == _selected.id,
                          onTap: () => setState(() => _selected = option),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.violet,
              ),
              onPressed: () => Navigator.of(context).pop(_selected),
              icon: const Icon(Icons.download_rounded),
              label: Text(
                context.tr(
                  'Download · about {size}',
                  arguments: {
                    'size': _formatDownloadBytes(_selected.estimatedBytes),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadOptionTile extends StatelessWidget {
  const _DownloadOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final OfflineDownloadOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.violet.withValues(alpha: 0.14)
              : colors.onSurface.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.violet
                : colors.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.violet
                      : colors.onSurface.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 12 : 0,
                height: selected ? 12 : 0,
                decoration: const BoxDecoration(
                  color: AppColors.violet,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          context.tr(option.title),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (option.recommended) ...[
                        const SizedBox(width: 8),
                        _OptionBadge(
                          label: context.tr('Recommended'),
                          color: AppColors.violet,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _localizedDescription(context),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.66),
                    ),
                  ),
                  if (option.nativeCompatibilityWarning) ...[
                    const SizedBox(height: 7),
                    Text(
                      context.tr(
                        'This original format may not play on this device.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              option.estimatedBytes > 0
                  ? '≈ ${_formatDownloadBytes(option.estimatedBytes)}'
                  : context.tr('Unknown size'),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  String _localizedDescription(BuildContext context) {
    return option.description
        .split(' · ')
        .map((part) {
          const prefix = 'Transcoded by ';
          if (part.startsWith(prefix)) {
            return context.tr(
              'Transcoded by {service}',
              arguments: {'service': part.substring(prefix.length)},
            );
          }
          return context.tr(part);
        })
        .join(' · ');
  }
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDownloadBytes(int bytes) {
  if (bytes <= 0) return '—';
  const gigabyte = 1024 * 1024 * 1024;
  const megabyte = 1024 * 1024;
  if (bytes >= gigabyte) {
    return '${(bytes / gigabyte).toStringAsFixed(1)} GB';
  }
  return '${(bytes / megabyte).toStringAsFixed(0)} MB';
}

class _DetailContent {
  const _DetailContent({
    this.details,
    this.ratings,
    this.recommendations = const [],
    this.similar = const [],
    this.episodeContext,
  });
  final SeerrMediaDetails? details;
  final SeerrRatings? ratings;
  final List<MediaViewModel> recommendations;
  final List<MediaViewModel> similar;
  final EpisodeMetadataContext? episodeContext;
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.title,
    required this.imageUrl,
    required this.details,
    required this.ratings,
    required this.media,
    required this.region,
  });

  final String title;
  final Uri? imageUrl;
  final SeerrMediaDetails? details;
  final SeerrRatings? ratings;
  final MediaViewModel media;
  final String region;

  @override
  Widget build(BuildContext context) {
    final releaseDate = details?.theatricalReleaseFor(region);
    final certification = details?.certificationFor(region);
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxHeight > 220;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.background),
            if (expanded && imageUrl != null)
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: double.infinity,
                  height: constraints.maxHeight,
                  child: Image.network(
                    imageUrl.toString(),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    frameBuilder: (context, child, frame, wasLoaded) =>
                        AnimatedOpacity(
                          opacity: wasLoaded || frame != null ? 1 : 0,
                          duration: const Duration(milliseconds: 450),
                          child: child,
                        ),
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x2208070D),
                    Color(0x6608070D),
                    AppColors.background,
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
            if (!expanded)
              Positioned(
                left: 58,
                right: 56,
                bottom: 15,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Positioned(
                left: 24,
                right: 24,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (media.statusLabel != null &&
                        media.lifecycleStatus !=
                            MediaLifecycleStatus.downloading)
                      _AvailabilityIndicator(
                        label: context.l10n.status(media.statusLabel!),
                        available:
                            media.lifecycleStatus ==
                            MediaLifecycleStatus.available,
                      ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.05,
                          ),
                    ),
                    if (media.kind == MediaKind.episode &&
                        media.subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 7),
                      Text(
                        media.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (releaseDate != null)
                          _HeroMetadata(
                            icon: Icons.calendar_today_outlined,
                            label: _formatReleaseDate(context, releaseDate),
                          ),
                        if (details?.runtimeMinutes != null)
                          _HeroMetadata(
                            icon: Icons.schedule_outlined,
                            label: '${details!.runtimeMinutes} min',
                          ),
                        if (certification != null)
                          _AgeRating(label: certification),
                      ],
                    ),
                    if (details?.genres.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      Text(
                        details!.genres
                            .map((genre) => genre.name)
                            .join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (_hasRatings(details, ratings)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          if ((details?.voteAverage ?? 0) > 0)
                            _RatingScore(
                              source: 'TMDB',
                              value: details!.voteAverage.toStringAsFixed(1),
                              color: AppColors.cyan,
                            ),
                          if (ratings?.imdbScore != null)
                            _RatingScore(
                              source: 'IMDb',
                              value: ratings!.imdbScore!.toStringAsFixed(1),
                              color: const Color(0xFFF5C518),
                            ),
                          if (ratings?.rottenTomatoesCriticsScore != null)
                            _RatingScore(
                              source: context.tr('Tomatometer'),
                              value:
                                  '${ratings!.rottenTomatoesCriticsScore!.round()}%',
                              color: const Color(0xFFFA320A),
                            ),
                          if (ratings?.rottenTomatoesAudienceScore != null)
                            _RatingScore(
                              source: context.tr('Rotten audience'),
                              value:
                                  '${ratings!.rottenTomatoesAudienceScore!.round()}%',
                              color: const Color(0xFFFFD447),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeroMetadata extends StatelessWidget {
  const _HeroMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Colors.white60),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.white)),
    ],
  );
}

class _AgeRating extends StatelessWidget {
  const _AgeRating({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.magenta),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: Text(
        context.tr('Age {rating}', arguments: {'rating': label}),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _RatingScore extends StatelessWidget {
  const _RatingScore({
    required this.source,
    required this.value,
    required this.color,
  });

  final String source;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 6),
      Text(
        '$source  ',
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _AvailabilityIndicator extends StatefulWidget {
  const _AvailabilityIndicator({required this.label, required this.available});

  final String label;
  final bool available;

  @override
  State<_AvailabilityIndicator> createState() => _AvailabilityIndicatorState();
}

class _AvailabilityIndicatorState extends State<_AvailabilityIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final Animation<double> _glow = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.available) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AvailabilityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.available == oldWidget.available) return;
    if (widget.available) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.available ? const Color(0xFF4ADE80) : AppColors.cyan;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              final animationEnabled =
                  widget.available && !MediaQuery.disableAnimationsOf(context);
              final value = animationEnabled ? _glow.value : 0.25;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 10 + (6 * value),
                    height: 10 + (6 * value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.08 + (0.16 * value)),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18 * value),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 6),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

enum _PlaybackMenuAction { restart, toggleWatched, download }

class _PlaybackOptionsMenu extends StatelessWidget {
  const _PlaybackOptionsMenu({
    required this.isWatched,
    required this.showDownload,
    required this.offlineDownload,
    required this.onPlayFromBeginning,
    required this.onSetWatched,
    required this.onDownload,
  });

  final bool isWatched;
  final bool showDownload;
  final OfflineDownload? offlineDownload;
  final VoidCallback onPlayFromBeginning;
  final ValueChanged<bool> onSetWatched;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: PopupMenuButton<_PlaybackMenuAction>(
        tooltip: context.tr('More playback options'),
        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
        onSelected: (action) {
          switch (action) {
            case _PlaybackMenuAction.restart:
              onPlayFromBeginning();
              break;
            case _PlaybackMenuAction.toggleWatched:
              onSetWatched(!isWatched);
              break;
            case _PlaybackMenuAction.download:
              onDownload();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _PlaybackMenuAction.restart,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.replay_rounded),
              title: Text(context.tr('Play from beginning')),
            ),
          ),
          PopupMenuItem(
            value: _PlaybackMenuAction.toggleWatched,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isWatched ? Icons.remove_done_rounded : Icons.done_all_rounded,
              ),
              title: Text(
                context.tr(isWatched ? 'Mark as unwatched' : 'Mark as watched'),
              ),
            ),
          ),
          if (showDownload)
            PopupMenuItem(
              value: _PlaybackMenuAction.download,
              enabled:
                  offlineDownload?.status !=
                      OfflineDownloadStatus.downloading &&
                  offlineDownload?.status != OfflineDownloadStatus.completed,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  offlineDownload?.status == OfflineDownloadStatus.completed
                      ? Icons.offline_pin_rounded
                      : Icons.download_for_offline_outlined,
                ),
                title: Text(
                  context.tr(
                    offlineDownload?.status == OfflineDownloadStatus.completed
                        ? 'Available offline'
                        : 'Download offline',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.trailer,
    required this.isAvailable,
    required this.media,
    required this.loading,
    required this.requested,
    required this.onPlay,
    required this.onRequest,
    required this.onRetry,
    required this.onDeleteRequest,
    required this.onDownload,
    required this.offlineDownload,
    required this.resume,
  });

  final SeerrRelatedVideo? trailer;
  final bool isAvailable;
  final MediaViewModel media;
  final bool loading;
  final bool requested;
  final VoidCallback onPlay;
  final VoidCallback onRequest;
  final VoidCallback onRetry;
  final VoidCallback onDeleteRequest;
  final VoidCallback onDownload;
  final OfflineDownload? offlineDownload;
  final bool resume;

  @override
  Widget build(BuildContext context) {
    final trailerButton = trailer?.url.isNotEmpty != true
        ? null
        : OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(trailer!.url),
              mode: LaunchMode.externalApplication,
            ),
            style: _largeSecondaryActionStyle(),
            icon: const Icon(Icons.play_circle_outline_rounded, size: 23),
            label: Text(context.tr('Watch trailer')),
          );
    final Widget? mediaButton =
        media.lifecycleStatus == MediaLifecycleStatus.downloading
        ? null
        : isAvailable
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.magenta,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(context.tr(resume ? 'Resume playback' : 'Play action')),
          )
        : _RequestAction(
            media: media,
            loading: loading,
            requested: requested,
            onRequest: onRequest,
            onRetry: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(52),
            ),
          );
    final primaryButton = mediaButton;
    final downloadButton =
        trailerButton == null &&
            isAvailable &&
            media.mediaServerItemId?.isNotEmpty == true
        ? OutlinedButton.icon(
            onPressed:
                offlineDownload?.status == OfflineDownloadStatus.downloading ||
                    offlineDownload?.status == OfflineDownloadStatus.completed
                ? null
                : onDownload,
            style: _largeSecondaryActionStyle(),
            icon: Icon(_downloadIcon, size: 23),
            label: Text(_downloadLabel(context)),
          )
        : null;
    final deleteRequestButton =
        media.lifecycleStatus == MediaLifecycleStatus.pendingApproval &&
            media.seerrRequestId != null
        ? OutlinedButton.icon(
            onPressed: loading ? null : onDeleteRequest,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.tr('Delete request')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          )
        : null;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (primaryButton != null)
            SizedBox(width: double.infinity, child: primaryButton),
          if (trailerButton != null || downloadButton != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: trailerButton ?? downloadButton!,
            ),
          ],
          if (deleteRequestButton != null) ...[
            const SizedBox(height: 10),
            deleteRequestButton,
          ],
        ],
      ),
    );
  }

  ButtonStyle _largeSecondaryActionStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white38,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
    );
  }

  IconData get _downloadIcon =>
      offlineDownload?.status == OfflineDownloadStatus.completed
      ? Icons.offline_pin_rounded
      : Icons.download_for_offline_outlined;

  String _downloadLabel(BuildContext context) =>
      switch (offlineDownload?.status) {
        OfflineDownloadStatus.downloading => context.tr(
          'Downloading · {progress}%',
          arguments: {
            'progress': ((offlineDownload?.progress ?? 0) * 100).round(),
          },
        ),
        OfflineDownloadStatus.completed => context.tr('Available offline'),
        OfflineDownloadStatus.failed => context.tr('Retry download'),
        null => context.tr('Download offline'),
      };
}

class _SeerrDownloadProgress extends StatelessWidget {
  const _SeerrDownloadProgress({required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress?.clamp(0.0, 1.0).toDouble();
    final percentage = normalizedProgress == null
        ? null
        : (normalizedProgress * 100).round();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            percentage == null
                ? context.tr('Downloading')
                : context.tr(
                    'Downloading · {progress}%',
                    arguments: {'progress': percentage},
                  ),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: normalizedProgress ?? 0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => LinearProgressIndicator(
                value: normalizedProgress == null ? null : value,
                minHeight: 6,
                backgroundColor: AppColors.white.withValues(alpha: 0.12),
                color: AppColors.violet,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestAction extends StatelessWidget {
  const _RequestAction({
    required this.media,
    required this.loading,
    required this.requested,
    required this.onRequest,
    required this.onRetry,
    this.style,
  });

  final MediaViewModel media;
  final bool loading;
  final bool requested;
  final VoidCallback onRequest;
  final VoidCallback onRetry;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final failed = media.lifecycleStatus == MediaLifecycleStatus.failed;
    final alreadyRequested =
        requested ||
        (media.lifecycleStatus != MediaLifecycleStatus.none &&
            media.lifecycleStatus != MediaLifecycleStatus.failed &&
            media.lifecycleStatus != MediaLifecycleStatus.declined);
    return FilledButton.icon(
      style: style,
      onPressed: loading || alreadyRequested
          ? null
          : failed
          ? onRetry
          : onRequest,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              failed
                  ? Icons.refresh_rounded
                  : alreadyRequested
                  ? Icons.schedule_rounded
                  : Icons.download_rounded,
            ),
      label: Text(
        failed
            ? context.tr('Retry request')
            : alreadyRequested
            ? context.l10n.status(media.statusLabel ?? 'Requested media')
            : context.tr('Request on Seerr'),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 22),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MoreInformation extends StatelessWidget {
  const _MoreInformation({required this.details, required this.region});

  final SeerrMediaDetails details;
  final String region;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          const Divider(),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 30),
              title: Text(
                context.tr('Learn more'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              subtitle: Text(
                context.tr('Crew, technical details and studios'),
                style: const TextStyle(color: Colors.white54),
              ),
              children: [
                _CreativeTeam(crew: details.crew),
                _TechnicalDetails(details: details, region: region),
                if (details.productionCompanies.isNotEmpty)
                  _Studios(companies: details.productionCompanies),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreativeTeam extends StatelessWidget {
  const _CreativeTeam({required this.crew});

  final List<SeerrCrewMember> crew;

  @override
  Widget build(BuildContext context) {
    final people = <SeerrCrewMember>[];
    final seen = <String>{};
    for (final person in crew) {
      final role = person.job ?? person.department;
      if (role == null || role.isEmpty || person.name.isEmpty) continue;
      final key = '$role:${person.name}';
      if (seen.add(key)) people.add(person);
      if (people.length == 8) break;
    }
    if (people.isEmpty) return const SizedBox.shrink();
    return _DetailSection(
      title: context.tr('Creative team'),
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        children: [
          for (final person in people)
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.job ?? person.department ?? '',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.46),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    person.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
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

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.details, required this.region});

  final SeerrMediaDetails details;
  final String region;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[
      if (details.originalTitle?.isNotEmpty == true)
        (context.tr('Original title'), details.originalTitle!),
      if (details.status?.isNotEmpty == true)
        (context.tr('Status'), details.status!),
      if (details.theatricalReleaseFor(region) != null)
        (
          context.tr('Release date'),
          _formatReleaseDate(context, details.theatricalReleaseFor(region)!),
        ),
      if (details.videoReleaseFor(region) != null)
        (
          context.tr('Video release date'),
          _formatReleaseDate(context, details.videoReleaseFor(region)!),
        ),
      if (details.certificationFor(region) != null)
        (context.tr('Age rating'), details.certificationFor(region)!),
      if (details.originalLanguage != null)
        (
          context.tr('Original language'),
          details.originalLanguage!.toUpperCase(),
        ),
      if (details.voteCount > 0) (context.tr('Votes'), '${details.voteCount}'),
      if ((details.budget ?? 0) > 0)
        (context.tr('Budget'), _formatBudget(details.budget!)),
      if ((details.revenue ?? 0) > 0)
        (context.tr('Revenue'), _formatBudget(details.revenue!)),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    return _DetailSection(
      title: context.tr('Technical details'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth >= 620
              ? (constraints.maxWidth - 28) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 28,
            runSpacing: 20,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: cellWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fact.$1,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.white.withValues(alpha: 0.46),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fact.$2,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Studios extends StatelessWidget {
  const _Studios({required this.companies});

  final List<SeerrCompany> companies;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: context.tr('Studios'),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final company in companies) Chip(label: Text(company.name)),
        ],
      ),
    );
  }
}

class _Cast extends StatelessWidget {
  const _Cast({required this.cast});
  final List<SeerrCastMember> cast;
  @override
  Widget build(BuildContext context) => _DetailSection(
    title: context.tr('Cast'),
    child: Column(
      children: [
        SizedBox(
          height: 184,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.take(14).length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final person = cast[index];
              return Semantics(
                button: true,
                label: person.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(46),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PersonDetailScreen(
                        personId: person.id,
                        initialName: person.name,
                        initialProfilePath: person.profilePath,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 39,
                          backgroundImage: person.profilePath == null
                              ? null
                              : NetworkImage(
                                  'https://image.tmdb.org/t/p/w185${person.profilePath}',
                                ),
                          child: person.profilePath == null
                              ? const Icon(Icons.person_rounded)
                              : null,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          person.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (person.character?.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            person.character!,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _Seasons extends StatefulWidget {
  const _Seasons({
    required this.tvId,
    required this.seasons,
    required this.availability,
    this.mediaServerSeriesId,
    this.currentSeasonNumber,
    this.currentEpisodeNumber,
    this.currentEpisodeWatched,
    required this.onEpisodeSelected,
  });
  final int tvId;
  final List<SeerrSeason> seasons;
  final List<SeerrMediaSeason> availability;
  final String? mediaServerSeriesId;
  final int? currentSeasonNumber;
  final int? currentEpisodeNumber;
  final bool? currentEpisodeWatched;
  final ValueChanged<SeasonEpisodeState> onEpisodeSelected;

  @override
  State<_Seasons> createState() => _SeasonsState();
}

class _SeasonsState extends State<_Seasons> {
  late int _selectedSeasonNumber =
      widget.seasons
          .where((season) => season.number == widget.currentSeasonNumber)
          .firstOrNull
          ?.number ??
      widget.seasons.where((season) => season.number > 0).firstOrNull?.number ??
      widget.seasons.first.number;

  @override
  Widget build(BuildContext context) {
    final selectedSeason = widget.seasons
        .where((season) => season.number == _selectedSeasonNumber)
        .first;
    final selectedAvailability = widget.availability
        .where((item) => item.number == selectedSeason.number)
        .firstOrNull
        ?.availability;
    return _DetailSection(
      title: context.tr('Seasons'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PopupMenuButton<int>(
            initialValue: _selectedSeasonNumber,
            tooltip: context.tr('Choose a season'),
            onSelected: (value) =>
                setState(() => _selectedSeasonNumber = value),
            itemBuilder: (context) => [
              for (final season in widget.seasons)
                PopupMenuItem(
                  value: season.number,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: season.number == _selectedSeasonNumber
                            ? Icon(
                                Icons.check_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          '${season.name} · ${context.l10n.episodes(season.episodeCount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.055),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.video_collection_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedSeason.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.episodes(selectedSeason.episodeCount),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white60,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SelectedSeasonEpisodes(
            key: ValueKey(_selectedSeasonNumber),
            tvId: widget.tvId,
            season: selectedSeason,
            availability: selectedAvailability,
            mediaServerSeriesId: widget.mediaServerSeriesId,
            currentEpisodeNumber:
                selectedSeason.number == widget.currentSeasonNumber
                ? widget.currentEpisodeNumber
                : null,
            currentEpisodeWatched:
                selectedSeason.number == widget.currentSeasonNumber
                ? widget.currentEpisodeWatched
                : null,
            onEpisodeSelected: widget.onEpisodeSelected,
          ),
        ],
      ),
    );
  }
}

class _SelectedSeasonEpisodes extends ConsumerStatefulWidget {
  const _SelectedSeasonEpisodes({
    required this.tvId,
    required this.season,
    required this.availability,
    required this.mediaServerSeriesId,
    required this.currentEpisodeNumber,
    required this.currentEpisodeWatched,
    required this.onEpisodeSelected,
    super.key,
  });

  final int tvId;
  final SeerrSeason season;
  final SeerrAvailability? availability;
  final String? mediaServerSeriesId;
  final int? currentEpisodeNumber;
  final bool? currentEpisodeWatched;
  final ValueChanged<SeasonEpisodeState> onEpisodeSelected;

  @override
  ConsumerState<_SelectedSeasonEpisodes> createState() =>
      _SelectedSeasonEpisodesState();
}

class _SelectedSeasonEpisodesState
    extends ConsumerState<_SelectedSeasonEpisodes> {
  late final Future<SeasonContent> _content = loadSeasonContent(
    seerr: ref.read(seerrClientProvider),
    mediaServer: ref.read(mediaServerClientProvider),
    tvId: widget.tvId,
    season: widget.season,
    language: ref.read(localeControllerProvider).value?.languageCode ?? 'en',
    fallbackAvailability: widget.availability,
    mediaServerSeriesId: widget.mediaServerSeriesId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<SeasonContent>(
    future: _content,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final content = snapshot.data;
      if (content == null) return const SizedBox.shrink();
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      content.season.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SeasonAvailability(availability: content.availability),
                ],
              ),
              const SizedBox(height: 8),
              SeasonEpisodesList(
                episodes: content.episodes,
                currentEpisodeNumber: widget.currentEpisodeNumber,
                currentEpisodeWatched: widget.currentEpisodeWatched,
                onEpisodeTap: widget.onEpisodeSelected,
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool _hasRatings(SeerrMediaDetails? details, SeerrRatings? ratings) {
  return (details?.voteAverage ?? 0) > 0 || ratings?.isEmpty == false;
}

String _regionForLocale(Locale locale) {
  return switch (locale.languageCode) {
    'fr' => 'FR',
    'es' => 'ES',
    'it' => 'IT',
    'de' => 'DE',
    _ => 'US',
  };
}

String _formatReleaseDate(BuildContext context, DateTime date) {
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatShortMonthDay(date)} ${date.year}';
}

String _formatBudget(int budget) {
  final digits = budget.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return 'USD ${buffer.toString()}';
}

Uri? _tmdbImage(String? path, String size) {
  if (path == null || path.isEmpty) return null;
  return Uri.https('image.tmdb.org', '/t/p/$size$path');
}
