import 'package:flutter_test/flutter_test.dart';
import 'package:seerrplay/features/player/domain/subtitle_cue.dart';

void main() {
  test('parses WebVTT cues and removes presentation tags', () {
    final cues = parseSubtitleCues('''
WEBVTT

00:00:01.250 --> 00:00:03.500 align:center
<i>Hello</i> &amp; welcome

00:04.000 --> 00:05.100
Second line
''');

    expect(cues, hasLength(2));
    expect(cues.first.start, const Duration(milliseconds: 1250));
    expect(cues.first.end, const Duration(milliseconds: 3500));
    expect(cues.first.text, 'Hello & welcome');
    expect(cues.last.text, 'Second line');
  });

  test('parses SRT timestamps and multiline text', () {
    final cues = parseSubtitleCues('''
1
00:01:02,100 --> 00:01:04,900
First line
Second line
''');

    expect(
      cues.single.start,
      const Duration(minutes: 1, seconds: 2, milliseconds: 100),
    );
    expect(cues.single.text, 'First line\nSecond line');
  });
}
