import 'package:flutter/material.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';

class MediaPosterCard extends StatelessWidget {
  const MediaPosterCard({
    required this.media,
    required this.onTap,
    this.width,
    this.showDetails = true,
    super.key,
  });

  final MediaViewModel media;
  final VoidCallback onTap;
  final double? width;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final progress = (media.downloadProgress ?? media.progress)
        ?.clamp(0.0, 1.0)
        .toDouble();
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PosterImage(url: media.posterUrl),
                    if (media.statusLabel != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: MediaStatusBadge(media: media),
                        ),
                      ),
                    if (progress != null && progress > 0)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.black54,
                          color: AppColors.violet,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showDetails)
              Padding(
                padding: const EdgeInsets.only(top: 9, left: 2, right: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (media.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        media.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.46),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MediaStatusBadge extends StatelessWidget {
  const MediaStatusBadge({required this.media, super.key});

  final MediaViewModel media;

  @override
  Widget build(BuildContext context) {
    if (media.lifecycleStatus == MediaLifecycleStatus.available) {
      return MediaAvailabilityDot(
        label: context.l10n.status(media.statusLabel ?? 'Available'),
      );
    }
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (media.lifecycleStatus) {
      MediaLifecycleStatus.downloading ||
      MediaLifecycleStatus.partiallyAvailable => (
        AppColors.cyan,
        AppColors.background,
      ),
      MediaLifecycleStatus.declined || MediaLifecycleStatus.failed => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      _ => (AppColors.magenta, AppColors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.status(media.statusLabel!),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MediaAvailabilityDot extends StatefulWidget {
  const MediaAvailabilityDot({required this.label, super.key});

  final String label;

  @override
  State<MediaAvailabilityDot> createState() => _MediaAvailabilityDotState();
}

class _MediaAvailabilityDotState extends State<MediaAvailabilityDot>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF4ADE80);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);
  late final Animation<double> _glow = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: SizedBox.square(
          dimension: 22,
          child: AnimatedBuilder(
            animation: _glow,
            builder: (context, child) {
              final value = MediaQuery.disableAnimationsOf(context)
                  ? 0.25
                  : _glow.value;
              return DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background.withValues(alpha: 0.66),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 9 + (6 * value),
                      height: 9 + (6 * value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _green.withValues(alpha: 0.08 + (0.18 * value)),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withValues(alpha: 0.2 * value),
                            blurRadius: 7,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _green,
                      ),
                      child: SizedBox.square(dimension: 7),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.url});

  final Uri? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const _PosterFallback();
    return Image.network(
      url.toString(),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _PosterFallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 42,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
