import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/downloads/domain/offline_download.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';

void main() {
  test('persists offline media metadata and creates a local media model', () {
    final download = OfflineDownload(
      id: 'profile_item',
      sourceItemId: 'series-1',
      downloadedItemId: 'episode-1',
      title: 'Series · Episode',
      kind: MediaKind.episode,
      filePath: '/downloads/episode.mp4',
      createdAt: DateTime.utc(2026, 7, 24),
      posterUrl: Uri.parse('https://images.example/poster.jpg'),
      tmdbId: 12,
      status: OfflineDownloadStatus.completed,
      progress: 1,
      downloadedBytes: 1024,
      totalBytes: 1024,
    );

    final restored = OfflineDownload.fromJson(download.toJson());
    final media = restored.toMediaViewModel();

    expect(restored.downloadedItemId, 'episode-1');
    expect(restored.status, OfflineDownloadStatus.completed);
    expect(media.localFilePath, '/downloads/episode.mp4');
    expect(media.kind, MediaKind.episode);
    expect(media.isAvailable, isTrue);
  });
}
