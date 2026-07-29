import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/media_server/data/media_browser_image_url.dart';

void main() {
  test('builds an image URL while preserving the server subpath', () {
    final url = mediaBrowserImageUrl(
      baseUrl: Uri.parse('https://media.example.test/jellyfin/'),
      itemId: 'item/with slash',
      imageType: 'Backdrop',
      tag: 'image-tag',
      index: 1,
      maxWidth: 1280,
      quality: 110,
    );

    expect(url.path, '/jellyfin/Items/item%2Fwith%20slash/Images/Backdrop');
    expect(url.queryParameters['tag'], 'image-tag');
    expect(url.queryParameters['index'], '1');
    expect(url.queryParameters['maxWidth'], '1280');
    expect(url.queryParameters['quality'], '100');
  });
}
