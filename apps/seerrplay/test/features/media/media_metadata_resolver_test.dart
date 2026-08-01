import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/media/application/media_metadata_resolver.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/profiles/domain/connection_profile.dart';

void main() {
  test('resolves the public series id from an episode parent', () async {
    final client = _MetadataClient({
      'episode': const MediaServerItem(
        id: 'episode',
        name: 'Episode',
        type: 'Episode',
        seriesId: 'series',
      ),
      'series': const MediaServerItem(
        id: 'series',
        name: 'Series',
        type: 'Series',
        providerIds: {'Tmdb': '1399'},
      ),
    });

    final context = await resolveEpisodeMetadata(
      mediaServer: client,
      episodeId: 'episode',
    );

    expect(context?.seriesTmdbId, 1399);
    expect(context?.seriesId, 'series');
  });

  test('returns null when the parent has no TMDB id', () async {
    final client = _MetadataClient({
      'episode': const MediaServerItem(
        id: 'episode',
        name: 'Episode',
        type: 'Episode',
        seriesId: 'series',
      ),
      'series': const MediaServerItem(
        id: 'series',
        name: 'Series',
        type: 'Series',
      ),
    });

    final context = await resolveEpisodeMetadata(
      mediaServer: client,
      episodeId: 'episode',
    );

    expect(context?.seriesTmdbId, isNull);
    expect(context?.seriesId, 'series');
  });
}

class _MetadataClient implements MediaServerClient {
  _MetadataClient(this.items);

  final Map<String, MediaServerItem> items;

  @override
  Future<String?> fetchSubtitleText(
    String itemId,
    MediaServerSource source,
    MediaStream stream,
  ) async => null;

  @override
  Future<MediaServerItem> getItemDetails(String itemId) async => items[itemId]!;

  @override
  MediaServerType get serverType => MediaServerType.jellyfin;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
