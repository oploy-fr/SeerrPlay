import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';

class EpisodeMetadataContext {
  const EpisodeMetadataContext({
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.seriesTmdbId,
    required this.episode,
  });

  final String seriesId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? seriesTmdbId;
  final MediaServerItem episode;
}

Future<EpisodeMetadataContext?> resolveEpisodeMetadata({
  required MediaServerClient mediaServer,
  required String episodeId,
}) async {
  final episode = await mediaServer.getItemDetails(episodeId);
  final seriesId = episode.seriesId;
  if (seriesId == null || seriesId.isEmpty) return null;

  final series = await mediaServer.getItemDetails(seriesId);
  final tmdbValue = series.providerIds.entries
      .where((entry) => entry.key.toLowerCase() == 'tmdb')
      .map((entry) => entry.value)
      .firstOrNull;
  return EpisodeMetadataContext(
    seriesId: seriesId,
    seasonNumber: episode.parentIndexNumber,
    episodeNumber: episode.indexNumber,
    seriesTmdbId: int.tryParse(tmdbValue ?? ''),
    episode: episode,
  );
}
