import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/profiles/domain/server_address.dart';

void main() {
  group('ServerAddress', () {
    test('builds an HTTPS address from a bare domain', () {
      final address = ServerAddress.parse(
        input: 'jellyfin.example.com',
        fallbackScheme: 'https',
      );

      expect(address.uri, Uri.parse('https://jellyfin.example.com'));
    });

    test('applies a custom port and keeps a base path', () {
      final address = ServerAddress.parse(
        input: 'media.example.com/jellyfin/',
        fallbackScheme: 'http',
        customPort: '8096',
      );

      expect(address.uri, Uri.parse('http://media.example.com:8096/jellyfin'));
    });

    test('honors a pasted protocol', () {
      final address = ServerAddress.parse(
        input: 'http://192.168.1.20:5055',
        fallbackScheme: 'https',
      );

      expect(address.scheme, 'http');
      expect(address.host, '192.168.1.20');
      expect(address.port, 5055);
    });

    test('rejects an invalid custom port', () {
      expect(
        () => ServerAddress.parse(
          input: 'seerr.example.com',
          fallbackScheme: 'https',
          customPort: '70000',
        ),
        throwsFormatException,
      );
    });
  });
}
