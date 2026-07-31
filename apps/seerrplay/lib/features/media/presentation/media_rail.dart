import 'package:flutter/material.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/core/widgets/desktop_hover_scale.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media/presentation/media_poster_card.dart';

class MediaRail extends StatelessWidget {
  const MediaRail({
    required this.title,
    required this.items,
    required this.onSelected,
    this.landscape = false,
    super.key,
  });

  final String title;
  final List<MediaViewModel> items;
  final ValueChanged<MediaViewModel> onSelected;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final desktop = isDesktopPlatform && width >= 1000;
    final isWide = width >= 900;
    final cardWidth = landscape
        ? desktop
              ? 370.0
              : isWide
              ? 320.0
              : 224.0
        : desktop
        ? 200.0
        : isWide
        ? 156.0
        : 112.0;
    final railHeight = landscape ? cardWidth * 9 / 16 + 50 : cardWidth * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              (desktop
                      ? Theme.of(context).textTheme.headlineSmall
                      : Theme.of(context).textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: desktop ? 20 : 14),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: desktop ? 22 : 14),
            itemBuilder: (context, index) {
              final media = items[index];
              if (landscape) {
                return _ContinueWatchingCard(
                  media: media,
                  width: cardWidth,
                  onTap: () => onSelected(media),
                );
              }
              return MediaPosterCard(
                media: media,
                width: cardWidth,
                showDetails: false,
                onTap: () => onSelected(media),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({
    required this.media,
    required this.width,
    required this.onTap,
  });

  final MediaViewModel media;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = media.progress?.clamp(0.0, 1.0).toDouble();
    final imageUrl = media.backdropUrl ?? media.posterUrl;
    return DesktopHoverScale(
      child: SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        Image.network(
                          imageUrl.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const _LandscapeFallback(),
                        )
                      else
                        const _LandscapeFallback(),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB308070D)],
                            stops: [0.55, 1],
                          ),
                        ),
                      ),
                      const Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xA608070D),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      if (progress != null && progress > 0)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                media.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (media.subtitle?.isNotEmpty == true)
                Text(
                  media.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapeFallback extends StatelessWidget {
  const _LandscapeFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        Icons.movie_outlined,
        size: 40,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
