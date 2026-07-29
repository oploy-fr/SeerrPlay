import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/theme/app_theme.dart';
import 'package:seerrplay/features/downloads/application/downloads_controller.dart';
import 'package:seerrplay/features/downloads/domain/offline_download.dart';
import 'package:seerrplay/features/player/presentation/player_screen.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Downloads'))),
      body: downloads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(context.tr('Unable to load offline downloads.')),
        ),
        data: (items) {
          if (items.isEmpty) return const _DownloadsEmptyState();
          final totalBytes = items
              .where(
                (download) =>
                    download.status == OfflineDownloadStatus.completed,
              )
              .fold<int>(
                0,
                (total, download) => total + download.downloadedBytes,
              );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 118),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _DownloadsSummary(
                  count: items.length,
                  totalBytes: totalBytes,
                );
              }
              final download = items[index - 1];
              return _DownloadTile(
                download: download,
                onPlay: download.status == OfflineDownloadStatus.completed
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              PlayerScreen(media: download.toMediaViewModel()),
                        ),
                      )
                    : null,
                onDelete: () => _confirmDelete(context, ref, download),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    OfflineDownload download,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete this download?')),
        content: Text(
          context.tr(
            'The offline copy of “{title}” will be removed from this device.',
            arguments: {'title': download.title},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(downloadsControllerProvider.notifier).delete(download.id);
    }
  }
}

class _DownloadsSummary extends StatelessWidget {
  const _DownloadsSummary({required this.count, required this.totalBytes});

  final int count;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.offline_pin_outlined,
            size: 19,
            color: AppColors.cyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr(
                '{count} offline · {size}',
                arguments: {'count': count, 'size': _formatBytes(totalBytes)},
              ),
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.download,
    required this.onPlay,
    required this.onDelete,
  });

  final OfflineDownload download;
  final VoidCallback? onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 68,
                height: 100,
                child: download.posterUrl == null
                    ? const ColoredBox(
                        color: AppColors.surface,
                        child: Icon(Icons.movie_outlined),
                      )
                    : Image.network(
                        download.posterUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(
                              color: AppColors.surface,
                              child: Icon(Icons.movie_outlined),
                            ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DownloadStatus(download: download),
                  if (download.status == OfflineDownloadStatus.downloading) ...[
                    const SizedBox(height: 9),
                    LinearProgressIndicator(
                      value: download.totalBytes > 0 ? download.progress : null,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onPlay != null)
              IconButton(
                tooltip: context.tr('Play offline'),
                onPressed: onPlay,
                icon: const Icon(Icons.play_circle_outline_rounded),
              ),
            IconButton(
              tooltip: context.tr('Delete download'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({required this.download});

  final OfflineDownload download;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (download.status) {
      OfflineDownloadStatus.downloading => (
        Icons.downloading_rounded,
        AppColors.cyan,
        download.totalBytes > 0
            ? context.tr(
                'Downloading · {progress}%',
                arguments: {'progress': (download.progress * 100).round()},
              )
            : context.tr('Preparing download…'),
      ),
      OfflineDownloadStatus.completed => (
        Icons.offline_pin_rounded,
        const Color(0xFF4ADE80),
        context.tr(
          'Available offline · {size}',
          arguments: {'size': _formatBytes(download.downloadedBytes)},
        ),
      ),
      OfflineDownloadStatus.failed => (
        Icons.error_outline_rounded,
        Theme.of(context).colorScheme.error,
        context.tr(download.error ?? 'Unable to download this media.'),
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _DownloadsEmptyState extends StatelessWidget {
  const _DownloadsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.download_for_offline_outlined,
              size: 62,
              color: AppColors.violet,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('No offline downloads'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              context.tr(
                'Download an available movie or episode to watch it without a connection.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final gigabytes = bytes / (1024 * 1024 * 1024);
  if (gigabytes >= 1) return '${gigabytes.toStringAsFixed(1)} GB';
  return '${(bytes / (1024 * 1024)).round()} MB';
}
