class ServerAddress {
  const ServerAddress({
    required this.scheme,
    required this.host,
    this.port,
    this.path = '',
  });

  final String scheme;
  final String host;
  final int? port;
  final String path;

  Uri get uri => Uri(
    scheme: scheme,
    host: host,
    port: port,
    path: path.isEmpty ? null : path,
  );

  static ServerAddress parse({
    required String input,
    required String fallbackScheme,
    String? customPort,
  }) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('Server domain is required.');
    }
    final hasScheme = RegExp(
      r'^https?://',
      caseSensitive: false,
    ).hasMatch(value);
    final parsed = Uri.tryParse(hasScheme ? value : '$fallbackScheme://$value');
    if (parsed == null ||
        !const {'http', 'https'}.contains(parsed.scheme.toLowerCase()) ||
        parsed.host.isEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw const FormatException('Invalid server domain.');
    }
    final parsedPort = customPort == null || customPort.trim().isEmpty
        ? (parsed.hasPort ? parsed.port : null)
        : int.tryParse(customPort.trim());
    if (parsedPort != null && (parsedPort < 1 || parsedPort > 65535)) {
      throw const FormatException('Invalid server port.');
    }
    return ServerAddress(
      scheme: parsed.scheme.toLowerCase(),
      host: parsed.host,
      port: parsedPort,
      path: _normalizePath(parsed.path),
    );
  }

  static ServerAddress fromUri(Uri uri) => ServerAddress(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: _normalizePath(uri.path),
  );

  static String _normalizePath(String value) {
    if (value.isEmpty || value == '/') return '';
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
