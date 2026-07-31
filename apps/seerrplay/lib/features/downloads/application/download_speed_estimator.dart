class DownloadSpeedEstimate {
  const DownloadSpeedEstimate({
    required this.bytesPerSecond,
    required this.remainingSeconds,
  });

  final double bytesPerSecond;
  final int remainingSeconds;
}

class DownloadSpeedEstimator {
  DownloadSpeedEstimator({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _lastUpdatedAt;
  int? _lastDownloadedBytes;
  double? _smoothedBytesPerSecond;

  DownloadSpeedEstimate? update({
    required int downloadedBytes,
    required int totalBytes,
  }) {
    final now = _clock();
    final previousTime = _lastUpdatedAt;
    final previousBytes = _lastDownloadedBytes;
    _lastUpdatedAt = now;
    _lastDownloadedBytes = downloadedBytes;
    if (previousTime == null ||
        previousBytes == null ||
        totalBytes <= downloadedBytes) {
      return null;
    }
    final elapsedSeconds = now.difference(previousTime).inMilliseconds / 1000;
    final addedBytes = downloadedBytes - previousBytes;
    if (elapsedSeconds <= 0 || addedBytes <= 0) return null;

    final currentSpeed = addedBytes / elapsedSeconds;
    _smoothedBytesPerSecond = _smoothedBytesPerSecond == null
        ? currentSpeed
        : (_smoothedBytesPerSecond! * 0.7) + (currentSpeed * 0.3);
    final speed = _smoothedBytesPerSecond!;
    return DownloadSpeedEstimate(
      bytesPerSecond: speed,
      remainingSeconds: ((totalBytes - downloadedBytes) / speed).ceil(),
    );
  }
}
