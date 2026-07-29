import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';

void main() {
  test('parses useful media metadata and ignores unexpected types', () {
    final item = MediaServerItem.fromJson({
      'Id': 'movie-1',
      'Name': 'Movie',
      'Type': 'Movie',
      'PremiereDate': '2024-02-03T00:00:00Z',
      'CommunityRating': 8,
      'ProviderIds': {'Tmdb': '42', 'Broken': 12},
      'ImageTags': {'Primary': 'primary-tag'},
      'BackdropImageTags': ['backdrop-tag', 12],
      'UserData': {
        'PlaybackPositionTicks': 1234,
        'IsFavorite': true,
        'Played': false,
      },
    });

    expect(item.id, 'movie-1');
    expect(item.premiereDate, DateTime.utc(2024, 2, 3));
    expect(item.communityRating, 8.0);
    expect(item.providerIds, {'Tmdb': '42'});
    expect(item.primaryImageTag, 'primary-tag');
    expect(item.backdropImageTags, ['backdrop-tag']);
    expect(item.userData?.playbackPositionTicks, 1234);
    expect(item.userData?.isFavorite, isTrue);
  });

  test('accepts a partial items response', () {
    final page = MediaServerItemsPage.fromJson({
      'Items': [
        {'Id': 'episode-1'},
        null,
      ],
    });

    expect(page.totalRecordCount, 1);
    expect(page.startIndex, 0);
    expect(page.items.single.id, 'episode-1');
    expect(page.items.single.name, isEmpty);
  });

  test('parses audio and subtitle tracks from a source', () {
    final playback = MediaServerPlaybackInfo.fromJson({
      'MediaSources': [
        {
          'Id': 'source-1',
          'DefaultAudioStreamIndex': 1,
          'MediaStreams': [
            {
              'Index': 1,
              'Type': 'Audio',
              'Language': 'fra',
              'Codec': 'aac',
              'Channels': 6,
              'IsDefault': true,
            },
            {
              'Index': 4,
              'Type': 'Subtitle',
              'DisplayTitle': 'Forced English',
              'IsForced': true,
            },
          ],
        },
      ],
    });

    final source = playback.mediaSources.single;
    expect(source.defaultAudioStreamIndex, 1);
    expect(source.audioStreams.single.label, 'FRA · AAC · 6 channels');
    expect(source.subtitleStreams.single.label, 'Forced English');
    expect(source.subtitleStreams.single.isForced, isTrue);
  });
}
