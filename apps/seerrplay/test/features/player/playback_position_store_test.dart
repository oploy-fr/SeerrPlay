import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/player/application/playback_position_store.dart';
import 'package:seerrplay/features/player/presentation/player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('keeps the most recent resume position', () {
    expect(latestResumeTicks(20, 10), 20);
    expect(latestResumeTicks(20, 30), 30);
  });

  test('persists an unfinished playback position', () async {
    const store = PlaybackPositionStore();
    await store.save(
      mediaKey: 'profile:movie',
      position: const Duration(minutes: 42),
      duration: const Duration(hours: 2),
    );

    expect(
      await store.loadTicks('profile:movie'),
      const Duration(minutes: 42).inMicroseconds * 10,
    );
  });

  test('clears the bookmark near the end', () async {
    const store = PlaybackPositionStore();
    await store.save(
      mediaKey: 'profile:movie',
      position: const Duration(minutes: 42),
      duration: const Duration(hours: 2),
    );
    await store.save(
      mediaKey: 'profile:movie',
      position: const Duration(minutes: 119),
      duration: const Duration(hours: 2),
    );

    expect(await store.loadTicks('profile:movie'), 0);
  });
}
