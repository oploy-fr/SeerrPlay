part of 'media_detail_screen.dart';

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
