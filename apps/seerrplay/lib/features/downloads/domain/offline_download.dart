import 'package:seerrplay/features/media/domain/media_view_model.dart';

enum OfflineDownloadStatus { downloading, completed, failed }

class OfflineDownload {
  const OfflineDownload({
    required this.id,
    required this.sourceItemId,
    required this.downloadedItemId,
    required this.title,
    required this.kind,
    required this.filePath,
    required this.createdAt,
    this.posterUrl,
    this.tmdbId,
    this.status = OfflineDownloadStatus.downloading,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.error,
  });

  factory OfflineDownload.fromJson(Map<String, dynamic> json) {
    final posterValue = json['posterUrl'] as String?;
    return OfflineDownload(
      id: json['id'] as String? ?? '',
      sourceItemId: json['sourceItemId'] as String? ?? '',
      downloadedItemId: json['downloadedItemId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      kind: MediaKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => MediaKind.unknown,
      ),
      filePath: json['filePath'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      posterUrl: posterValue?.isNotEmpty == true
          ? Uri.tryParse(posterValue!)
          : null,
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      status: OfflineDownloadStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => OfflineDownloadStatus.failed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }

  final String id;
  final String sourceItemId;
  final String downloadedItemId;
  final String title;
  final MediaKind kind;
  final String filePath;
  final DateTime createdAt;
  final Uri? posterUrl;
  final int? tmdbId;
  final OfflineDownloadStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  OfflineDownload copyWith({
    OfflineDownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? error,
  }) {
    return OfflineDownload(
      id: id,
      sourceItemId: sourceItemId,
      downloadedItemId: downloadedItemId,
      title: title,
      kind: kind,
      filePath: filePath,
      createdAt: createdAt,
      posterUrl: posterUrl,
      tmdbId: tmdbId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: error,
    );
  }

  MediaViewModel toMediaViewModel() => MediaViewModel(
    id: 'offline:$id',
    title: title,
    kind: kind,
    posterUrl: posterUrl,
    tmdbId: tmdbId,
    mediaServerItemId: downloadedItemId,
    localFilePath: filePath,
    isAvailable: true,
    lifecycleStatus: MediaLifecycleStatus.available,
    statusLabel: 'Available offline',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceItemId': sourceItemId,
    'downloadedItemId': downloadedItemId,
    'title': title,
    'kind': kind.name,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'posterUrl': posterUrl?.toString(),
    'tmdbId': tmdbId,
    'status': status.name,
    'progress': progress,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'error': error,
  };
}
