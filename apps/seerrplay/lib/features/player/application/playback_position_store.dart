import 'package:shared_preferences/shared_preferences.dart';

class PlaybackPositionStore {
  const PlaybackPositionStore();

  static const _prefix = 'playback_position_v1';

  Future<int> loadTicks(String mediaKey) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_key(mediaKey)) ?? 0;
  }

  Future<void> save({
    required String mediaKey,
    required Duration position,
    required Duration duration,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(mediaKey);
    final nearlyFinished =
        duration > Duration.zero &&
        (position >= duration - const Duration(minutes: 2) ||
            position.inMilliseconds / duration.inMilliseconds >= 0.95);
    if (position < const Duration(seconds: 5) || nearlyFinished) {
      await preferences.remove(key);
      return;
    }
    await preferences.setInt(key, position.inMicroseconds * 10);
  }

  Future<void> clear(String mediaKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(mediaKey));
  }

  String _key(String mediaKey) => '$_prefix.$mediaKey';
}
