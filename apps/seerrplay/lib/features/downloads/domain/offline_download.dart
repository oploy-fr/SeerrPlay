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
    this.ageRating,
    this.status = OfflineDownloadStatus.downloading,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0,
    this.estimatedRemainingSeconds,
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
      ageRating: json['ageRating'] as String?,
      status: OfflineDownloadStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => OfflineDownloadStatus.failed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      bytesPerSecond: (json['bytesPerSecond'] as num?)?.toDouble() ?? 0,
      estimatedRemainingSeconds: (json['estimatedRemainingSeconds'] as num?)
          ?.toInt(),
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
  final String? ageRating;
  final OfflineDownloadStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final int? estimatedRemainingSeconds;
  final String? error;

  OfflineDownload copyWith({
    String? filePath,
    OfflineDownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    double? bytesPerSecond,
    int? estimatedRemainingSeconds,
    String? error,
  }) {
    return OfflineDownload(
      id: id,
      sourceItemId: sourceItemId,
      downloadedItemId: downloadedItemId,
      title: title,
      kind: kind,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt,
      posterUrl: posterUrl,
      tmdbId: tmdbId,
      ageRating: ageRating,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      estimatedRemainingSeconds:
          estimatedRemainingSeconds ?? this.estimatedRemainingSeconds,
      error: error,
    );
  }

  MediaViewModel toMediaViewModel() => MediaViewModel(
    id: 'offline:$id',
    title: title,
    kind: kind,
    posterUrl: posterUrl,
    tmdbId: tmdbId,
    ageRating: ageRating,
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
    'ageRating': ageRating,
    'status': status.name,
    'progress': progress,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'bytesPerSecond': bytesPerSecond,
    'estimatedRemainingSeconds': estimatedRemainingSeconds,
    'error': error,
  };
}
