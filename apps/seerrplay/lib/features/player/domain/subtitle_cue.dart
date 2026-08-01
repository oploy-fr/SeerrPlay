class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

List<SubtitleCue> parseSubtitleCues(String source) {
  final normalized = source
      .replaceFirst('\ufeff', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final cues = <SubtitleCue>[];
  for (final block in normalized.split(RegExp(r'\n{2,}'))) {
    final lines = block
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final timingIndex = lines.indexWhere((line) => line.contains('-->'));
    if (timingIndex < 0 || timingIndex == lines.length - 1) continue;
    final timing = lines[timingIndex].split('-->');
    if (timing.length != 2) continue;
    final start = _parseTimestamp(timing.first.trim());
    final end = _parseTimestamp(timing.last.trim().split(RegExp(r'\s+')).first);
    if (start == null || end == null || end <= start) continue;
    final text = lines
        .skip(timingIndex + 1)
        .join('\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAllMapped(
          RegExp(r'&(?:amp|lt|gt|quot|apos);'),
          (match) => const {
            '&amp;': '&',
            '&lt;': '<',
            '&gt;': '>',
            '&quot;': '"',
            '&apos;': "'",
          }[match.group(0)]!,
        )
        .trim();
    if (text.isNotEmpty) {
      cues.add(SubtitleCue(start: start, end: end, text: text));
    }
  }
  cues.sort((left, right) => left.start.compareTo(right.start));
  return cues;
}

Duration? _parseTimestamp(String value) {
  final parts = value.replaceAll(',', '.').split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final seconds = double.tryParse(parts.last);
  final minutes = int.tryParse(parts[parts.length - 2]);
  final hours = parts.length == 3 ? int.tryParse(parts.first) : 0;
  if (seconds == null || minutes == null || hours == null) return null;
  return Duration(
    milliseconds: ((hours * 3600 + minutes * 60 + seconds) * 1000).round(),
  );
}
