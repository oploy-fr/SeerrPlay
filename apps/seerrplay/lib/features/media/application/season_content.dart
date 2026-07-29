import 'package:dio/dio.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/seerr/data/seerr_client.dart';
import 'package:seerrplay/features/seerr/domain/seerr_models.dart';

class SeasonEpisodeState {
  const SeasonEpisodeState({
    required this.episode,
    required this.mediaServerItem,
  });

  final SeerrEpisode episode;
  final MediaServerItem? mediaServerItem;

  bool get isAvailable => mediaServerItem != null;
  bool get isWatched => mediaServerItem?.userData?.played == true;
}

class SeasonContent {
  const SeasonContent({
    required this.season,
    required this.episodes,
    required this.availability,
  });

  final SeerrSeason season;
  final List<SeasonEpisodeState> episodes;
  final SeerrAvailability? availability;
}

MediaServerItem? nextUnwatchedEpisode(
  List<MediaServerItem> episodes, {
  required String currentEpisodeId,
}) {
  final ordered = episodes.where((item) => item.type == 'Episode').toList()
    ..sort((left, right) {
      final seasonComparison = (left.parentIndexNumber ?? 0).compareTo(
        right.parentIndexNumber ?? 0,
      );
      if (seasonComparison != 0) return seasonComparison;
      return (left.indexNumber ?? 0).compareTo(right.indexNumber ?? 0);
    });
  final currentIndex = ordered.indexWhere(
    (episode) => episode.id == currentEpisodeId,
  );
  final remaining = currentIndex < 0 ? ordered : ordered.skip(currentIndex + 1);
  return remaining
      .where((episode) => episode.userData?.played != true)
      .firstOrNull;
}

Future<SeasonContent> loadSeasonContent({
  required SeerrClient seerr,
  required MediaServerClient mediaServer,
  required int tvId,
  required SeerrSeason season,
  required String language,
  required SeerrAvailability? fallbackAvailability,
  String? mediaServerSeriesId,
}) async {
  final details = await seerr.tvSeasonDetails(
    tvId,
    season.number,
    language: language,
  );
  var mediaServerEpisodes = const <MediaServerItem>[];
  if (mediaServerSeriesId?.isNotEmpty == true) {
    try {
      mediaServerEpisodes = await mediaServer.getSeriesEpisodes(
        mediaServerSeriesId!,
        seasonNumber: season.number,
      );
    } on DioException {
      mediaServerEpisodes = const [];
    } on FormatException {
      mediaServerEpisodes = const [];
    }
  }
  return mergeSeasonContent(
    season: details,
    mediaServerEpisodes: mediaServerEpisodes,
    fallbackAvailability: fallbackAvailability,
  );
}

SeasonContent mergeSeasonContent({
  required SeerrSeason season,
  required List<MediaServerItem> mediaServerEpisodes,
  required SeerrAvailability? fallbackAvailability,
}) {
  final availableByNumber = <int, MediaServerItem>{
    for (final episode in mediaServerEpisodes)
      if (episode.indexNumber != null) episode.indexNumber!: episode,
  };
  final availableCount = availableByNumber.length;
  final allListedEpisodesAvailable =
      season.episodes.isNotEmpty &&
      season.episodes.every(
        (episode) => availableByNumber.containsKey(episode.number),
      );
  final availability = availableCount == 0
      ? fallbackAvailability
      : allListedEpisodesAvailable
      ? SeerrAvailability.available
      : SeerrAvailability.partiallyAvailable;
  return SeasonContent(
    season: season,
    availability: availability,
    episodes: season.episodes
        .map(
          (episode) => SeasonEpisodeState(
            episode: episode,
            mediaServerItem: availableByNumber[episode.number],
          ),
        )
        .toList(growable: false),
  );
}
