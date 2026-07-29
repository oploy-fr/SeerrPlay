import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/player/presentation/player_screen.dart';

void main() {
  test('starts automatic PiP only when the app actually leaves the screen', () {
    expect(shouldStartAutomaticPip(AppLifecycleState.inactive), isFalse);
    expect(shouldStartAutomaticPip(AppLifecycleState.resumed), isFalse);
    expect(shouldStartAutomaticPip(AppLifecycleState.hidden), isTrue);
    expect(shouldStartAutomaticPip(AppLifecycleState.paused), isTrue);
  });
}
