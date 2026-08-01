import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/core/widgets/app_page_layout.dart';
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

part 'media_detail_content.dart';
part 'media_detail_downloads.dart';
part 'media_detail_sections.dart';

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
        final desktop = AppPageLayout.usesLargeScreenLayout(context);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: desktop ? 560 : 380,
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
                    constraints: BoxConstraints(
                      maxWidth: desktop ? 1360 : 1100,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 52 : 24,
                        desktop ? 36 : 24,
                        desktop ? 52 : 24,
                        desktop ? 80 : 50,
                      ),
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
                          if (offlineDownload != null)
                            _OfflineDownloadPanel(
                              download: offlineDownload,
                              onRetry: () => _download(downloadableMedia),
                              onDelete: () => ref
                                  .read(downloadsControllerProvider.notifier)
                                  .delete(offlineDownload.id),
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
