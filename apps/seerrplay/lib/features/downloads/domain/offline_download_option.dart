import 'package:seerrplay/features/media_server/domain/media_server_models.dart';

enum OfflineDownloadMode { original, compatible }

class OfflineDownloadOption {
  const OfflineDownloadOption({
    required this.id,
    required this.mode,
    required this.title,
    required this.description,
    required this.estimatedBytes,
    required this.container,
    this.maxVideoBitrate,
    this.maxWidth,
    this.maxHeight,
    this.recommended = false,
    this.nativeCompatibilityWarning = false,
  });

  final String id;
  final OfflineDownloadMode mode;
  final String title;
  final String description;
  final int estimatedBytes;
  final String container;
  final int? maxVideoBitrate;
  final int? maxWidth;
  final int? maxHeight;
  final bool recommended;
  final bool nativeCompatibilityWarning;

  bool get transcodes => mode == OfflineDownloadMode.compatible;
}

class OfflineDownloadPreparation {
  const OfflineDownloadPreparation({
    required this.sourceItemId,
    required this.playableItem,
    required this.mediaSource,
    required this.options,
  });

  final String sourceItemId;
  final MediaServerItem playableItem;
  final MediaServerSource mediaSource;
  final List<OfflineDownloadOption> options;
}
