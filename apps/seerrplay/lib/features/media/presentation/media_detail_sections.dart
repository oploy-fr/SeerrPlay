part of 'media_detail_screen.dart';

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
