import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/media/application/season_content.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

void main() {
  const season = SeerrSeason(
    id: 10,
    number: 2,
    name: 'Season 2',
    // TMDB can advertise a future episode before returning it in the visible
    // episode list. Availability must follow the episodes actually displayed.
    episodeCount: 3,
    episodes: [
      SeerrEpisode(id: 21, name: 'One', number: 1, seasonNumber: 2),
      SeerrEpisode(id: 22, name: 'Two', number: 2, seasonNumber: 2),
    ],
  );

  test('marks a complete server season as available', () {
    final content = mergeSeasonContent(
      season: season,
      fallbackAvailability: SeerrAvailability.unknown,
      mediaServerEpisodes: const [
        MediaServerItem(
          id: 'episode-1',
          name: 'One',
          type: 'Episode',
          indexNumber: 1,
          userData: MediaServerUserData(played: true),
        ),
        MediaServerItem(
          id: 'episode-2',
          name: 'Two',
          type: 'Episode',
          indexNumber: 2,
        ),
      ],
    );

    expect(content.availability, SeerrAvailability.available);
    expect(content.episodes.first.isWatched, isTrue);
    expect(content.episodes.last.isAvailable, isTrue);
  });

  test('marks an incomplete server season as partially available', () {
    final content = mergeSeasonContent(
      season: season,
      fallbackAvailability: SeerrAvailability.unknown,
      mediaServerEpisodes: const [
        MediaServerItem(
          id: 'episode-1',
          name: 'One',
          type: 'Episode',
          indexNumber: 1,
        ),
      ],
    );

    expect(content.availability, SeerrAvailability.partiallyAvailable);
    expect(content.episodes.first.isAvailable, isTrue);
    expect(content.episodes.last.isAvailable, isFalse);
  });

  test('selects the next unwatched episode across seasons', () {
    final next = nextUnwatchedEpisode(const [
      MediaServerItem(
        id: 's1e2',
        name: 'S1E2',
        type: 'Episode',
        parentIndexNumber: 1,
        indexNumber: 2,
        userData: MediaServerUserData(played: true),
      ),
      MediaServerItem(
        id: 's2e1',
        name: 'S2E1',
        type: 'Episode',
        parentIndexNumber: 2,
        indexNumber: 1,
      ),
      MediaServerItem(
        id: 's1e1',
        name: 'S1E1',
        type: 'Episode',
        parentIndexNumber: 1,
        indexNumber: 1,
        userData: MediaServerUserData(played: true),
      ),
    ], currentEpisodeId: 's1e2');

    expect(next?.id, 's2e1');
  });
}
