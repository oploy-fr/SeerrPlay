enum MediaKind { movie, series, episode, unknown }

enum MediaLifecycleStatus {
  none,
  pendingApproval,
  requested,
  downloading,
  partiallyAvailable,
  available,
  declined,
  failed,
}

class MediaViewModel {
  const MediaViewModel({
    required this.id,
    required this.title,
    required this.kind,
    this.subtitle,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.tmdbId,
    this.mediaServerItemId,
    this.localFilePath,
    this.isAvailable = false,
    this.progress,
    this.lifecycleStatus = MediaLifecycleStatus.none,
    this.statusLabel,
    this.downloadProgress,
    this.seerrRequestId,
  });

  final String id;
  final String title;
  final MediaKind kind;
  final String? subtitle;
  final String? overview;
  final Uri? posterUrl;
  final Uri? backdropUrl;
  final int? tmdbId;
  final String? mediaServerItemId;
  final String? localFilePath;
  final bool isAvailable;
  final double? progress;
  final MediaLifecycleStatus lifecycleStatus;
  final String? statusLabel;
  final double? downloadProgress;
  final int? seerrRequestId;

  bool get hasPlaybackProgress => (progress ?? 0) > 0;

  MediaViewModel copyWith({
    String? mediaServerItemId,
    String? localFilePath,
    bool? isAvailable,
    MediaLifecycleStatus? lifecycleStatus,
    String? statusLabel,
    double? downloadProgress,
    int? seerrRequestId,
  }) {
    return MediaViewModel(
      id: id,
      title: title,
      kind: kind,
      subtitle: subtitle,
      overview: overview,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      tmdbId: tmdbId,
      mediaServerItemId: mediaServerItemId ?? this.mediaServerItemId,
      localFilePath: localFilePath ?? this.localFilePath,
      isAvailable: isAvailable ?? this.isAvailable,
      progress: progress,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      statusLabel: statusLabel ?? this.statusLabel,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      seerrRequestId: seerrRequestId ?? this.seerrRequestId,
    );
  }

  MediaViewModel withoutRequestStatus() {
    return MediaViewModel(
      id: id,
      title: title,
      kind: kind,
      subtitle: subtitle,
      overview: overview,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      tmdbId: tmdbId,
      mediaServerItemId: mediaServerItemId,
      localFilePath: localFilePath,
      isAvailable: isAvailable,
      progress: progress,
    );
  }

  MediaViewModel withRequestStatus({
    required MediaLifecycleStatus lifecycleStatus,
    required String? statusLabel,
    required double? downloadProgress,
    String? mediaServerItemId,
    bool? isAvailable,
    int? seerrRequestId,
  }) {
    return MediaViewModel(
      id: id,
      title: title,
      kind: kind,
      subtitle: subtitle,
      overview: overview,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      tmdbId: tmdbId,
      mediaServerItemId: mediaServerItemId ?? this.mediaServerItemId,
      localFilePath: localFilePath,
      isAvailable: isAvailable ?? this.isAvailable,
      progress: progress,
      lifecycleStatus: lifecycleStatus,
      statusLabel: statusLabel,
      downloadProgress: downloadProgress,
      seerrRequestId: seerrRequestId ?? this.seerrRequestId,
    );
  }
}
