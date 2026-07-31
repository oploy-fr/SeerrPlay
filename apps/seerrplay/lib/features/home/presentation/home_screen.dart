import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/app/presentation/app_navigation_bar.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/core/widgets/seerr_brand_logo.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/downloads/presentation/downloads_screen.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/home/application/home_state.dart';
import 'package:seerrplay/features/home/presentation/category_screen.dart';
import 'package:seerrplay/features/home/presentation/media_server_library_screen.dart';
import 'package:seerrplay/features/home/presentation/provider_screen.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_detail_screen.dart';
import 'package:seerrplay/features/media/presentation/media_poster_card.dart';
import 'package:seerrplay/features/media/presentation/media_rail.dart';
import 'package:seerrplay/features/profiles/application/profiles_controller.dart';
import 'package:seerrplay/features/profiles/presentation/profile_avatar.dart';
import 'package:seerrplay/features/profiles/presentation/profile_selection_screen.dart';
import 'package:seerrplay/features/profiles/presentation/profile_setup_screen.dart';
import 'package:seerrplay/features/requests/presentation/requests_screen.dart';
import 'package:seerrplay/features/search/presentation/search_screen.dart';
import 'package:seerrplay/features/settings/presentation/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profilesControllerProvider).requireValue;
    final activeProfile = profileState.activeProfile!;
    final requestCount = ref.watch(userRequestsProvider).value?.length ?? 0;
    final pages = [
      const _HomeDashboard(),
      const SearchScreen(),
      const RequestsScreen(),
      const DownloadsScreen(),
      SettingsScreen(
        activeProfile: activeProfile,
        profiles: profileState.profiles,
        connectionStatus: context.tr('Connected'),
        onSelectProfile: (profileId) {
          ref
              .read(profilesControllerProvider.notifier)
              .selectProfile(profileId);
          setState(() => _index = 0);
        },
        onAddProfile: _addProfile,
        onReconnect: () =>
            ref.read(appSessionControllerProvider.notifier).disconnect(),
        onDeleteProfile: () => _deleteProfile(activeProfile.id),
        onContentRestrictionsChanged: (enabled, maximumAge) {
          ref
              .read(profilesControllerProvider.notifier)
              .updateContentRestrictions(
                profileId: activeProfile.id,
                childMode: enabled,
                maximumContentAge: maximumAge,
              );
        },
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
        destinations: [
          AppNavigationDestination(
            icon: Icons.home_outlined,
            label: context.tr('Home navigation'),
          ),
          AppNavigationDestination(
            icon: Icons.search_outlined,
            label: context.tr('Search'),
          ),
          AppNavigationDestination(
            icon: Icons.inbox_outlined,
            label: context.tr('Requests'),
            badge: requestCount,
          ),
          AppNavigationDestination(
            icon: Icons.download_for_offline_outlined,
            label: context.tr('Downloads'),
          ),
          AppNavigationDestination(
            icon: Icons.settings_outlined,
            label: context.tr('Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => ProfileSetupScreen(
          onCompleted: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  Future<void> _deleteProfile(String profileId) async {
    await ref.read(credentialStoreProvider).deleteProfile(profileId);
    await ref
        .read(profilesControllerProvider.notifier)
        .deleteProfile(profileId);
  }
}

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard();

  void _open(BuildContext context, MediaViewModel media) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MediaDetailScreen(media: media)),
    );
  }

  Future<void> _chooseProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (pickerContext) => ProfileSelectionScreen(
          showBackButton: true,
          onProfileSelected: (profileId) => Navigator.of(pickerContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionControllerProvider).requireValue;
    final content = ref.watch(homeContentProvider);
    final availableRequests = ref.watch(availableUnwatchedRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const SeerrBrandLogo(compact: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Tooltip(
              message: context.tr('Switch profile'),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _chooseProfile(context),
                child: Row(
                  children: [
                    if (MediaQuery.sizeOf(context).width >= 520) ...[
                      Text(
                        session.profile!.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: 10),
                    ],
                    ProfileAvatar(
                      avatarIndex: session.profile!.avatarIndex,
                      size: 34,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref.read(seerrClientProvider).clearCache();
          ref.invalidate(userRequestsProvider);
          return ref.refresh(homeContentProvider.future);
        },
        child: content.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(28),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.cloud_off_rounded, size: 54),
              const SizedBox(height: 18),
              Text(
                context.tr('Unable to load Home'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'Pull down to try again. If the session expired, reconnect the services in Settings.',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          data: (data) {
            final hasMedia =
                data.continueWatching.isNotEmpty ||
                data.trending.isNotEmpty ||
                data.popularMovies.isNotEmpty ||
                data.popularSeries.isNotEmpty;
            final hasConnectionIssue = data.serviceIssues.isNotEmpty;
            if (!hasMedia && hasConnectionIssue) {
              return _HomeConnectionState(
                issues: data.serviceIssues,
                onRetry: () {
                  ref.read(seerrClientProvider).clearCache();
                  ref.invalidate(userRequestsProvider);
                  ref.invalidate(homeContentProvider);
                },
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 118),
              children: [
                _TrendingHeroSlider(
                  items: data.trending,
                  onSelected: (media) => _open(context, media),
                ),
                if (data.trending.isNotEmpty) const SizedBox(height: 24),
                _CategoryButtons(categories: data.categories),
                if (data.categories.isNotEmpty) const SizedBox(height: 26),
                MediaRail(
                  title: context.tr('Continue watching'),
                  items: data.continueWatching,
                  landscape: true,
                  onSelected: (media) => _open(context, media),
                ),
                if (data.continueWatching.isNotEmpty)
                  const SizedBox(height: 30),
                availableRequests.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (items) => MediaRail(
                    title: context.tr('Your available requests'),
                    items: items,
                    onSelected: (media) => _open(context, media),
                  ),
                ),
                if (availableRequests.value?.isNotEmpty == true)
                  const SizedBox(height: 30),
                MediaRail(
                  title: context.tr('Popular movies'),
                  items: data.popularMovies,
                  onSelected: (media) => _open(context, media),
                ),
                if (data.popularMovies.isNotEmpty) const SizedBox(height: 30),
                MediaRail(
                  title: context.tr('Popular series'),
                  items: data.popularSeries,
                  onSelected: (media) => _open(context, media),
                ),
                if (data.popularSeries.isNotEmpty) const SizedBox(height: 30),
                _Providers(
                  providers: data.providers,
                  region: data.providerRegion,
                ),
                if (data.continueWatching.isEmpty &&
                    data.trending.isEmpty &&
                    data.popularMovies.isEmpty &&
                    data.popularSeries.isEmpty) ...[
                  const SizedBox(height: 100),
                  Center(child: Text(context.tr('No media to display.'))),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeConnectionState extends StatelessWidget {
  const _HomeConnectionState({required this.issues, required this.onRetry});

  final List<HomeServiceIssue> issues;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 96, 28, 118),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.magenta.withValues(alpha: 0.24),
                        AppColors.violet.withValues(alpha: 0.12),
                        AppColors.cyan.withValues(alpha: 0.18),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  context.tr('Unable to reach your media services'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Unable to connect to the media server or Seerr. Check your connection or contact your media server administrator.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.62),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                for (var index = 0; index < issues.length; index++) ...[
                  _ServiceIssueRow(issue: issues[index]),
                  if (index != issues.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('Try again')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceIssueRow extends StatelessWidget {
  const _ServiceIssueRow({required this.issue});

  final HomeServiceIssue issue;

  @override
  Widget build(BuildContext context) {
    final service = switch (issue.service) {
      HomeService.mediaServer => 'Media server',
      HomeService.seerr => 'Seerr',
    };
    final message = switch (issue.kind) {
      HomeServiceIssueKind.unauthorized => context.tr(
        'The {service} session has expired.',
        arguments: {'service': service},
      ),
      HomeServiceIssueKind.forbidden => context.tr(
        'Access was forbidden by {service}.',
        arguments: {'service': service},
      ),
      HomeServiceIssueKind.timeout => context.tr(
        '{service} did not respond in time.',
        arguments: {'service': service},
      ),
      HomeServiceIssueKind.unreachable => context.tr(
        'No response from {service}.',
        arguments: {'service': service},
      ),
      HomeServiceIssueKind.server => context.tr(
        '{service} returned a server error.',
        arguments: {'service': service},
      ),
      HomeServiceIssueKind.unknown => context.tr(
        'Unexpected {service} error.',
        arguments: {'service': service},
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5A6E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            issue.code,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.cyan,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryButtons extends StatelessWidget {
  const _CategoryButtons({required this.categories});

  final List<HomeCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final colors = _categoryColors(category.name, index);
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CategoryScreen(category: category),
              ),
            ),
            child: Container(
              width: 166,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.last.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (category.imageUrl != null)
                    Image.network(
                      category.imageUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.first.withValues(alpha: 0.2),
                          colors.last.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 12,
                    bottom: 13,
                    child: Row(
                      children: [
                        Icon(
                          category.type.name == 'movie'
                              ? Icons.movie_outlined
                              : Icons.tv_outlined,
                          size: 18,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

List<Color> _categoryColors(String name, int index) {
  final normalized = name.toLowerCase();
  if (normalized.contains('action') || normalized.contains('aventure')) {
    return const [Color(0xFFFF8243), AppColors.magenta];
  }
  if (normalized.contains('com') || normalized.contains('animation')) {
    return const [AppColors.cyan, Color(0xFF2962FF)];
  }
  if (normalized.contains('hor') || normalized.contains('crime')) {
    return const [Color(0xFF8A1538), Color(0xFF31104A)];
  }
  if (normalized.contains('rom') || normalized.contains('drama')) {
    return const [AppColors.magenta, AppColors.violet];
  }
  if (normalized.contains('science') || normalized.contains('fant')) {
    return const [AppColors.violet, AppColors.cyan];
  }
  const palettes = [
    [AppColors.violet, Color(0xFF4B2BC7)],
    [AppColors.magenta, Color(0xFF8A245D)],
    [AppColors.cyan, Color(0xFF1267A8)],
    [Color(0xFFFFB02E), Color(0xFFDC4D2F)],
  ];
  return palettes[index % palettes.length];
}

class _TrendingHeroSlider extends StatefulWidget {
  const _TrendingHeroSlider({required this.items, required this.onSelected});

  final List<MediaViewModel> items;
  final ValueChanged<MediaViewModel> onSelected;

  @override
  State<_TrendingHeroSlider> createState() => _TrendingHeroSliderState();
}

class _TrendingHeroSliderState extends State<_TrendingHeroSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.94);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _TrendingHeroSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!_controller.hasClients || !mounted) return;
      final itemCount = widget.items.length > 8 ? 8 : widget.items.length;
      final nextPage = (_page + 1) % itemCount;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items.take(8).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final height = width >= 900
        ? 390.0
        : width >= 600
        ? 320.0
        : 235.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final media = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _TrendingHeroCard(
                  media: media,
                  rank: index + 1,
                  onTap: () => widget.onSelected(media),
                ),
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < items.length; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: _page == index ? 22 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _page == index ? AppColors.violet : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrendingHeroCard extends StatelessWidget {
  const _TrendingHeroCard({
    required this.media,
    required this.rank,
    required this.onTap,
  });

  final MediaViewModel media;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media.backdropUrl != null)
              Image.network(
                media.backdropUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: AppColors.elevatedSurface),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [Colors.transparent, Color(0xE608070D)],
                  stops: [0.25, 1],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB308070D)],
                  stops: [0.5, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 24,
              bottom: 20,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Trending rank', arguments: {'rank': rank}),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                    ),
                    if (media.overview?.isNotEmpty == true &&
                        MediaQuery.sizeOf(context).width >= 600) ...[
                      const SizedBox(height: 10),
                      Text(
                        media.overview!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (media.statusLabel != null)
              Positioned(
                top: 16,
                right: 16,
                child: media.lifecycleStatus == MediaLifecycleStatus.available
                    ? MediaAvailabilityDot(
                        label: context.l10n.status(media.statusLabel!),
                      )
                    : MediaStatusBadge(media: media),
              ),
          ],
        ),
      ),
    );
  }
}

class _Providers extends StatelessWidget {
  const _Providers({required this.providers, required this.region});

  final List<HomeProvider> providers;
  final String region;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Providers · {region}', arguments: {'region': region}),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: providers.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Tooltip(
                  message: context.tr('Media library'),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MediaServerLibraryScreen(),
                      ),
                    ),
                    child: Container(
                      width: 78,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFAA5CC3), Color(0xFF00A4DC)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.video_library_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                );
              }
              final provider = providers[index - 1];
              return Tooltip(
                message: provider.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ProviderScreen(provider: provider, region: region),
                    ),
                  ),
                  child: Container(
                    width: 78,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: provider.logoUrl == null
                        ? const Icon(Icons.live_tv_rounded, color: Colors.black)
                        : Image.network(
                            provider.logoUrl.toString(),
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
