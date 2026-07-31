import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/downloads/application/download_speed_estimator.dart';

void main() {
  test('estimates remaining time from transferred bytes', () {
    var now = DateTime.utc(2026);
    final estimator = DownloadSpeedEstimator(clock: () => now);

    expect(estimator.update(downloadedBytes: 100, totalBytes: 1100), isNull);
    now = now.add(const Duration(seconds: 1));
    final estimate = estimator.update(downloadedBytes: 200, totalBytes: 1100);

    expect(estimate?.bytesPerSecond, 100);
    expect(estimate?.remainingSeconds, 9);
  });

  test('ignores samples that do not advance', () {
    var now = DateTime.utc(2026);
    final estimator = DownloadSpeedEstimator(clock: () => now);
    estimator.update(downloadedBytes: 100, totalBytes: 1000);
    now = now.add(const Duration(seconds: 1));

    expect(estimator.update(downloadedBytes: 100, totalBytes: 1000), isNull);
  });
}
