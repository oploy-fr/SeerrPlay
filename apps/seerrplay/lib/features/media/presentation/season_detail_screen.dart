import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/media/application/season_content.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

class SeasonDetailScreen extends ConsumerStatefulWidget {
  const SeasonDetailScreen({
    required this.tvId,
    required this.season,
    this.availability,
    this.mediaServerSeriesId,
    super.key,
  });

  final int tvId;
  final SeerrSeason season;
  final SeerrAvailability? availability;
  final String? mediaServerSeriesId;

  @override
  ConsumerState<SeasonDetailScreen> createState() => _SeasonDetailScreenState();
}

class _SeasonDetailScreenState extends ConsumerState<SeasonDetailScreen> {
  late final Future<SeasonContent> _content = loadSeasonContent(
    seerr: ref.read(seerrClientProvider),
    mediaServer: ref.read(mediaServerClientProvider),
    tvId: widget.tvId,
    season: widget.season,
    language: ref.read(localeControllerProvider).value?.languageCode ?? 'en',
    fallbackAvailability: widget.availability,
    mediaServerSeriesId: widget.mediaServerSeriesId,
  );
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      await ref.read(seerrClientProvider).requestTvSeasons(widget.tvId, [
        widget.season.number,
      ]);
      ref.invalidate(userRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Season requested on Seerr.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.season.name)),
      body: FutureBuilder<SeasonContent>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(context.tr('Season unavailable.')));
          }
          final content = snapshot.data!;
          final season = content.season;
          final canRequest =
              content.availability == null ||
              content.availability == SeerrAvailability.unknown;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              SeasonAvailability(availability: content.availability),
              const SizedBox(height: 16),
              if (season.overview?.isNotEmpty == true) ...[
                Text(season.overview!),
                const SizedBox(height: 18),
              ],
              if (canRequest) ...[
                FilledButton.icon(
                  onPressed: _requesting ? null : _request,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    context.tr(
                      _requesting ? 'Requesting…' : 'Request this season',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                context.tr('Episodes'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              SeasonEpisodesList(episodes: content.episodes),
            ],
          );
        },
      ),
    );
  }
}

class SeasonAvailability extends StatelessWidget {
  const SeasonAvailability({required this.availability, super.key});

  final SeerrAvailability? availability;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (availability) {
      SeerrAvailability.available => (
        'Season available',
        Icons.check_circle_rounded,
      ),
      SeerrAvailability.partiallyAvailable => (
        'Season partially available',
        Icons.incomplete_circle_rounded,
      ),
      SeerrAvailability.processing ||
      SeerrAvailability.pending => ('Season requested', Icons.schedule_rounded),
      _ => ('Season unavailable', Icons.remove_circle_outline_rounded),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(avatar: Icon(icon, size: 18), label: Text(context.tr(label))),
    );
  }
}

class SeasonEpisodesList extends StatelessWidget {
  const SeasonEpisodesList({
    required this.episodes,
    this.currentEpisodeNumber,
    this.currentEpisodeWatched,
    this.onEpisodeTap,
    super.key,
  });

  final List<SeasonEpisodeState> episodes;
  final int? currentEpisodeNumber;
  final bool? currentEpisodeWatched;
  final ValueChanged<SeasonEpisodeState>? onEpisodeTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (index, state) in episodes.indexed) ...[
        Builder(
          builder: (context) {
            final isCurrent = state.episode.number == currentEpisodeNumber;
            final isWatched = isCurrent && currentEpisodeWatched != null
                ? currentEpisodeWatched!
                : state.isWatched;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: isCurrent
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: isCurrent
                    ? Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.45),
                      )
                    : null,
              ),
              child: ListTile(
                onTap: state.isAvailable && onEpisodeTap != null
                    ? () => onEpisodeTap!(state)
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                leading: state.episode.stillPath == null
                    ? const SizedBox(width: 80, child: Icon(Icons.tv_rounded))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          'https://image.tmdb.org/t/p/w300${state.episode.stillPath}',
                          width: 100,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                title: Text('${state.episode.number}. ${state.episode.name}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCurrent) ...[
                      const SizedBox(height: 3),
                      Text(
                        context.tr('Currently watching'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (state.episode.overview != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        state.episode.overview!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isWatched)
                      Tooltip(
                        message: context.tr('Watched'),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4ADE80),
                        ),
                      )
                    else if (state.isAvailable)
                      Tooltip(
                        message: context.tr('Available'),
                        child: const Icon(
                          Icons.circle,
                          size: 9,
                          color: Color(0xFF4ADE80),
                        ),
                      ),
                    if (state.isAvailable && onEpisodeTap != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        if (index < episodes.length - 1) const Divider(height: 1),
      ],
    ],
  );
}
