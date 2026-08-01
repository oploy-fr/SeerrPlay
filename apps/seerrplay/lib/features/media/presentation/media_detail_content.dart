part of 'media_detail_screen.dart';

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
    final desktop = AppPageLayout.usesLargeScreenLayout(context);
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
                left: desktop ? 64 : 24,
                right: desktop ? MediaQuery.sizeOf(context).width * 0.32 : 24,
                bottom: desktop ? 44 : 20,
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
                      style:
                          (desktop
                                  ? Theme.of(context).textTheme.displayMedium
                                  : Theme.of(context).textTheme.headlineMedium)
                              ?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                height: 1.05,
                              ),
                    ),
                    if (media.kind == MediaKind.episode &&
                        media.subtitle?.isNotEmpty == true) ...[
                      SizedBox(height: desktop ? 12 : 7),
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
                    SizedBox(height: desktop ? 18 : 11),
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

class _OfflineDownloadPanel extends StatelessWidget {
  const _OfflineDownloadPanel({
    required this.download,
    required this.onRetry,
    required this.onDelete,
  });

  final OfflineDownload download;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final completed = download.status == OfflineDownloadStatus.completed;
    final failed = download.status == OfflineDownloadStatus.failed;
    final color = completed
        ? const Color(0xFF4ADE80)
        : failed
        ? Theme.of(context).colorScheme.error
        : AppColors.cyan;
    final percentage = (download.progress.clamp(0, 1) * 100).round();
    final title = completed
        ? context.tr('Downloaded to this device')
        : failed
        ? context.tr('Unable to download this media.')
        : context.tr(
            download.estimatedRemainingSeconds == null
                ? 'Downloading · {progress}%'
                : 'Downloading · {progress}% · {time} left',
            arguments: {
              'progress': percentage,
              if (download.estimatedRemainingSeconds case final seconds?)
                'time': _formatDownloadRemaining(seconds),
            },
          );
    final transferred = completed
        ? _formatDownloadBytes(download.downloadedBytes)
        : download.totalBytes > 0
        ? context.tr(
            '{downloaded} of {total}',
            arguments: {
              'downloaded': _formatDownloadBytes(download.downloadedBytes),
              'total': _formatDownloadBytes(download.totalBytes),
            },
          )
        : _formatDownloadBytes(download.downloadedBytes);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.offline_pin_rounded
                : failed
                ? Icons.error_outline_rounded
                : Icons.downloading_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  failed
                      ? context.tr(download.error ?? 'Retry download')
                      : transferred,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                  ),
                ),
                if (!completed && !failed) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: download.totalBytes > 0
                          ? download.progress.clamp(0, 1)
                          : null,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      color: color,
                    ),
                  ),
                ],
                if (failed) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.tr('Retry download')),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Delete download'),
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

String _formatDownloadRemaining(int seconds) {
  if (seconds < 60) return '< 1 min';
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return remainingMinutes == 0 ? '$hours h' : '$hours h $remainingMinutes min';
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
