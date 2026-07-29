import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/localization/locale_controller.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_detail_screen.dart';
import 'package:seerrplay/features/media/presentation/media_rail.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  const PersonDetailScreen({
    required this.personId,
    required this.initialName,
    this.initialProfilePath,
    super.key,
  });

  final int personId;
  final String initialName;
  final String? initialProfilePath;

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  late final Future<_PersonContent> _content = _load();

  Future<_PersonContent> _load() async {
    final client = ref.read(seerrClientProvider);
    final language =
        ref.read(localeControllerProvider).value?.languageCode ?? 'en';
    final results = await Future.wait<Object>([
      client.personDetails(widget.personId, language: language),
      client.personCredits(widget.personId, language: language),
    ]);
    return _PersonContent(
      details: results[0] as SeerrPersonDetails,
      credits: results[1] as SeerrPersonCredits,
    );
  }

  void _openMedia(MediaViewModel media) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MediaDetailScreen(media: media)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_PersonContent>(
        future: _content,
        builder: (context, snapshot) {
          final details = snapshot.data?.details;
          final profilePath = details?.profilePath ?? widget.initialProfilePath;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 390,
                pinned: true,
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: _PersonHero(
                  name: details?.name ?? widget.initialName,
                  department: details?.knownForDepartment,
                  profilePath: profilePath,
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
                      child: switch (snapshot.connectionState) {
                        ConnectionState.none ||
                        ConnectionState.waiting ||
                        ConnectionState.active => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        ConnectionState.done when snapshot.hasError => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.person_off_outlined,
                                size: 46,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                context.tr('Unable to load this person.'),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        ConnectionState.done => _PersonBody(
                          content: snapshot.data!,
                          onMediaSelected: _openMedia,
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonContent {
  const _PersonContent({required this.details, required this.credits});

  final SeerrPersonDetails details;
  final SeerrPersonCredits credits;
}

class _PersonHero extends StatelessWidget {
  const _PersonHero({
    required this.name,
    required this.department,
    required this.profilePath,
  });

  final String name;
  final String? department;
  final String? profilePath;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profilePath == null
        ? null
        : 'https://image.tmdb.org/t/p/h632$profilePath';
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxHeight > 180;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.background),
            if (expanded && imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
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
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x2208070D),
                    Color(0xA008070D),
                    AppColors.background,
                  ],
                  stops: [0, 0.58, 0.92],
                ),
              ),
            ),
            Positioned(
              left: expanded ? 24 : 58,
              right: 24,
              bottom: expanded ? 24 : 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: expanded ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: expanded
                        ? Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          )
                        : Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                  if (expanded && department?.isNotEmpty == true) ...[
                    const SizedBox(height: 7),
                    Text(
                      department!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w600,
                      ),
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

class _PersonBody extends StatelessWidget {
  const _PersonBody({required this.content, required this.onMediaSelected});

  final _PersonContent content;
  final ValueChanged<MediaViewModel> onMediaSelected;

  @override
  Widget build(BuildContext context) {
    final details = content.details;
    final appearances = _uniqueCredits(
      content.credits.cast,
    ).map(_mediaFromCredit).toList(growable: false);
    final crewAppearances = _uniqueCredits(
      content.credits.crew,
    ).map(_mediaFromCredit).toList(growable: false);
    final facts = <(String, String)>[
      if (details.birthday != null)
        (
          context.tr('Born'),
          MaterialLocalizations.of(context).formatMediumDate(details.birthday!),
        ),
      if (details.deathday != null)
        (
          context.tr('Died'),
          MaterialLocalizations.of(context).formatMediumDate(details.deathday!),
        ),
      if (details.placeOfBirth?.isNotEmpty == true)
        (context.tr('Place of birth'), details.placeOfBirth!),
      if (details.knownForDepartment.isNotEmpty)
        (context.tr('Known for'), details.knownForDepartment),
      if (details.alsoKnownAs.isNotEmpty)
        (context.tr('Also known as'), details.alsoKnownAs.take(4).join(', ')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facts.isNotEmpty) _PersonalFacts(facts: facts),
        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 22),
        Text(
          context.tr('Biography'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Text(
          details.biography.isEmpty
              ? context.tr('No biography available.')
              : details.biography,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
        ),
        if (appearances.isNotEmpty) ...[
          const SizedBox(height: 38),
          MediaRail(
            title: context.tr('Appearances'),
            items: appearances,
            onSelected: onMediaSelected,
          ),
        ],
        if (crewAppearances.isNotEmpty) ...[
          const SizedBox(height: 34),
          MediaRail(
            title: context.tr('Behind the camera'),
            items: crewAppearances,
            onSelected: onMediaSelected,
          ),
        ],
      ],
    );
  }
}

class _PersonalFacts extends StatelessWidget {
  const _PersonalFacts({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 30,
      runSpacing: 20,
      children: [
        for (final fact in facts)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fact.$1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.46),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fact.$2,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

List<SeerrPersonCredit> _uniqueCredits(List<SeerrPersonCredit> credits) {
  final sorted = [...credits]
    ..sort((left, right) => right.popularity.compareTo(left.popularity));
  final seen = <String>{};
  return sorted
      .where(
        (credit) =>
            credit.title.isNotEmpty &&
            (credit.type == SeerrMediaType.movie ||
                credit.type == SeerrMediaType.tv) &&
            seen.add('${credit.type.apiValue}:${credit.id}'),
      )
      .take(30)
      .toList(growable: false);
}

MediaViewModel _mediaFromCredit(SeerrPersonCredit credit) {
  final lifecycle = mediaInfoLifecycle(credit.mediaInfo);
  final available = credit.mediaInfo?.availability;
  final role = credit.character ?? credit.job;
  final year = credit.releaseDate?.year;
  return MediaViewModel(
    id: 'person:${credit.type.apiValue}:${credit.id}',
    title: credit.title,
    subtitle: [
      if (role?.isNotEmpty == true) role!,
      if (year != null) '$year',
    ].join(' · '),
    overview: credit.overview,
    kind: credit.type == SeerrMediaType.movie
        ? MediaKind.movie
        : MediaKind.series,
    posterUrl: credit.posterPath == null
        ? null
        : Uri.parse('https://image.tmdb.org/t/p/w500${credit.posterPath}'),
    backdropUrl: credit.backdropPath == null
        ? null
        : Uri.parse('https://image.tmdb.org/t/p/w1280${credit.backdropPath}'),
    tmdbId: credit.id,
    mediaServerItemId: credit.mediaInfo?.mediaServerItemId,
    isAvailable:
        available == SeerrAvailability.available ||
        available == SeerrAvailability.partiallyAvailable,
    lifecycleStatus: lifecycle.$1,
    statusLabel: lifecycle.$2,
    downloadProgress: lifecycle.$3,
  );
}
