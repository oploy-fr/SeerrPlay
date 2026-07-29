import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/home/application/home_controller.dart';
import 'package:seerrplay/features/jellyfin/data/jellyfin_client.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';

void main() {
  test('merges current media and next episodes by last playback date', () {
    final items = mergeContinueWatchingItems(
      resumeItems: [
        _item(
          id: 'movie-current',
          type: 'Movie',
          lastPlayedDate: DateTime.utc(2026, 7, 22),
        ),
        _item(
          id: 'episode-current',
          type: 'Episode',
          seriesId: 'series-current',
          lastPlayedDate: DateTime.utc(2026, 7, 20),
        ),
      ],
      nextUpItems: [
        _item(
          id: 'episode-next-recent',
          type: 'Episode',
          seriesId: 'series-recent',
        ),
        _item(
          id: 'episode-next-current',
          type: 'Episode',
          seriesId: 'series-current',
        ),
        _item(id: 'episode-next-old', type: 'Episode', seriesId: 'series-old'),
      ],
      recentlyPlayedEpisodes: [
        _item(
          id: 'episode-previous-recent',
          type: 'Episode',
          seriesId: 'series-recent',
          lastPlayedDate: DateTime.utc(2026, 7, 23),
        ),
        _item(
          id: 'episode-previous-old',
          type: 'Episode',
          seriesId: 'series-old',
          lastPlayedDate: DateTime.utc(2026, 7, 10),
        ),
      ],
    );

    expect(items.map((item) => item.id), [
      'episode-next-recent',
      'movie-current',
      'episode-current',
      'episode-next-old',
    ]);
  });

  test('keeps API order when playback dates are unavailable', () {
    final items = mergeContinueWatchingItems(
      resumeItems: [_item(id: 'resume', type: 'Movie')],
      nextUpItems: [
        _item(id: 'next-one', type: 'Episode', seriesId: 'series-one'),
        _item(id: 'next-two', type: 'Episode', seriesId: 'series-two'),
      ],
      recentlyPlayedEpisodes: const [],
    );

    expect(items.map((item) => item.id), ['resume', 'next-one', 'next-two']);
  });

  test('uses the episode frame as its landscape artwork', () {
    final client = JellyfinClient(
      baseUrl: Uri.parse('https://media.example.test'),
      deviceId: 'test-device',
    );
    final media = mediaFromServer(
      const MediaServerItem(
        id: 'episode-id',
        name: 'Episode title',
        type: 'Episode',
        seriesName: 'Series title',
        imageTags: {'Primary': 'episode-frame'},
        backdropImageTags: ['series-backdrop'],
      ),
      client,
    );

    expect(media.backdropUrl, media.posterUrl);
    expect(media.backdropUrl?.path, '/Items/episode-id/Images/Primary');
    expect(media.backdropUrl?.queryParameters['tag'], 'episode-frame');
    expect(media.backdropUrl?.queryParameters['maxWidth'], '960');
  });

  test('does not expose zero playback as resumable progress', () {
    final client = JellyfinClient(
      baseUrl: Uri.parse('https://media.example.test'),
      deviceId: 'test-device',
    );
    final media = mediaFromServer(
      const MediaServerItem(
        id: 'movie-id',
        name: 'Movie',
        type: 'Movie',
        runTimeTicks: 100000,
        userData: MediaServerUserData(playbackPositionTicks: 0),
      ),
      client,
    );

    expect(media.progress, isNull);
    expect(media.hasPlaybackProgress, isFalse);
  });
}

MediaServerItem _item({
  required String id,
  required String type,
  String? seriesId,
  DateTime? lastPlayedDate,
}) {
  return MediaServerItem(
    id: id,
    name: id,
    type: type,
    seriesId: seriesId,
    userData: MediaServerUserData(lastPlayedDate: lastPlayedDate),
  );
}
