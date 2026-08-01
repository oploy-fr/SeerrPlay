part of 'player_screen.dart';

class _PlayerSettingsSheet extends StatefulWidget {
  const _PlayerSettingsSheet({
    required this.source,
    required this.serverName,
    required this.videoSize,
    required this.selectedAudioIndex,
    required this.selectedSubtitleIndex,
    required this.maxStreamingBitrate,
    required this.playbackSpeed,
    required this.playerFit,
    required this.onAudioChanged,
    required this.onSubtitleChanged,
    required this.onQualityChanged,
    required this.onSpeedChanged,
    required this.onFitChanged,
  });

  final MediaServerSource? source;
  final String serverName;
  final Size? videoSize;
  final int? selectedAudioIndex;
  final int? selectedSubtitleIndex;
  final int? maxStreamingBitrate;
  final double playbackSpeed;
  final _PlayerFit playerFit;
  final ValueChanged<int?> onAudioChanged;
  final ValueChanged<int?> onSubtitleChanged;
  final ValueChanged<int?> onQualityChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<_PlayerFit> onFitChanged;

  @override
  State<_PlayerSettingsSheet> createState() => _PlayerSettingsSheetState();
}

class _PlayerSettingsSheetState extends State<_PlayerSettingsSheet> {
  late double _playbackSpeed = widget.playbackSpeed;
  late _PlayerFit _playerFit = widget.playerFit;

  @override
  Widget build(BuildContext context) {
    final audioStreams = widget.source?.audioStreams ?? const [];
    final subtitleStreams = widget.source?.subtitleStreams ?? const [];
    final automaticQualityDetails = _automaticQualityDetails(context);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(
              context.tr('Playback settings'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            _SettingsSection(
              icon: Icons.high_quality_rounded,
              title: 'Quality',
              bottomSpacing:
                  widget.maxStreamingBitrate == null &&
                      automaticQualityDetails.isNotEmpty
                  ? 12
                  : 24,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quality in _PlayerQuality.values)
                    ChoiceChip(
                      label: Text(
                        quality.bitrate == null
                            ? 'Auto · ${widget.serverName}'
                            : context.tr(quality.label),
                      ),
                      selected: quality.bitrate == widget.maxStreamingBitrate,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: quality.bitrate == widget.maxStreamingBitrate
                            ? Colors.white
                            : null,
                      ),
                      onSelected: (_) =>
                          widget.onQualityChanged(quality.bitrate),
                    ),
                ],
              ),
            ),
            if (widget.maxStreamingBitrate == null &&
                automaticQualityDetails.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              'Stream selected by {service}',
                              arguments: {'service': widget.serverName},
                            ),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            automaticQualityDetails,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _SettingsSection(
              icon: Icons.speed_rounded,
              title: 'Speed',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final speed in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                    ChoiceChip(
                      label: Text('${speed}x'),
                      selected: speed == _playbackSpeed,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: speed == _playbackSpeed ? Colors.white : null,
                      ),
                      onSelected: (_) {
                        setState(() => _playbackSpeed = speed);
                        widget.onSpeedChanged(speed);
                      },
                    ),
                ],
              ),
            ),
            _SettingsSection(
              icon: Icons.aspect_ratio_rounded,
              title: 'Picture format',
              child: SegmentedButton<_PlayerFit>(
                segments: [
                  for (final fit in _PlayerFit.values)
                    ButtonSegment(
                      value: fit,
                      label: Text(context.tr(fit.label)),
                      icon: Icon(fit.icon),
                    ),
                ],
                selected: {_playerFit},
                onSelectionChanged: (selection) {
                  setState(() => _playerFit = selection.first);
                  widget.onFitChanged(selection.first);
                },
              ),
            ),
            _SettingsSection(
              icon: Icons.audiotrack_rounded,
              title: 'Audio',
              child: audioStreams.isEmpty
                  ? Text(context.tr('No other audio track available'))
                  : RadioGroup<int>(
                      groupValue: widget.selectedAudioIndex,
                      onChanged: widget.onAudioChanged,
                      child: Column(
                        children: [
                          for (final stream in audioStreams)
                            RadioListTile<int>(
                              contentPadding: EdgeInsets.zero,
                              value: stream.index,
                              title: Text(context.l10n.status(stream.label)),
                              secondary: stream.isDefault
                                  ? const Icon(
                                      Icons.check_circle_outline_rounded,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
            ),
            _SettingsSection(
              icon: Icons.subtitles_rounded,
              title: 'Subtitles',
              child: RadioGroup<int>(
                groupValue: widget.selectedSubtitleIndex ?? -1,
                onChanged: (index) =>
                    widget.onSubtitleChanged(index == -1 ? null : index),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: -1,
                      title: Text(context.tr('Off')),
                    ),
                    for (final stream in subtitleStreams)
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        value: stream.index,
                        title: Text(context.l10n.status(stream.label)),
                        secondary: stream.isForced
                            ? Text(context.tr('Forced'))
                            : stream.isDefault
                            ? Text(context.tr('Default'))
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _automaticQualityDetails(BuildContext context) {
    final source = widget.source;
    if (source == null) return '';
    final videoStream = source.mediaStreams
        .where((stream) => stream.type == MediaStreamType.video)
        .firstOrNull;
    final reportedSize = widget.videoSize;
    final width = reportedSize != null && reportedSize.width > 0
        ? reportedSize.width.round()
        : videoStream?.width;
    final height = reportedSize != null && reportedSize.height > 0
        ? reportedSize.height.round()
        : videoStream?.height;
    final bitrate = videoStream?.bitRate ?? source.bitrate;
    final codec = videoStream?.codec?.trim().toUpperCase();
    final details = <String>[
      if (height != null && height > 0)
        '${_resolutionLabel(height)}${width != null && width > 0 ? ' ($width×$height)' : ''}',
      if (bitrate != null && bitrate > 0) _formatBitrate(bitrate),
      if (codec?.isNotEmpty == true) codec!,
      source.playMethod == 'Transcode'
          ? context.tr(
              'Transcoded by {service}',
              arguments: {'service': widget.serverName},
            )
          : context.tr(
              source.playMethod == 'DirectPlay'
                  ? 'Direct play'
                  : 'Direct stream',
            ),
    ];
    return details.join(' · ');
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.child,
    this.bottomSpacing = 24,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottomSpacing),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              context.tr(title),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

enum _PlayerFit {
  cover('Fill screen', Icons.crop_free_rounded, BoxFit.cover),
  contain('Fit image', Icons.fit_screen_rounded, BoxFit.contain);

  const _PlayerFit(this.label, this.icon, this.fit);
  final String label;
  final IconData icon;
  final BoxFit fit;
}

enum _PlayerQuality {
  auto('Auto', null),
  ultraHd('4K · 40 Mb/s', 40000000),
  fullHd('1080p · 20 Mb/s', 20000000),
  fullHdLight('1080p · 10 Mb/s', 10000000),
  hd('720p · 5 Mb/s', 5000000),
  mobile('Mobile · 2 Mb/s', 2000000);

  const _PlayerQuality(this.label, this.bitrate);
  final String label;
  final int? bitrate;
}

class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 16),
          Text(context.tr('Unable to play')),
          const SizedBox(height: 8),
          Text(context.tr(message), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.tr('Back')),
              ),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.tr('Try again')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.abs();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _resolutionLabel(int height) {
  if (height >= 2000) return '4K';
  if (height >= 1400) return '1440p';
  if (height >= 1000) return '1080p';
  if (height >= 700) return '720p';
  if (height >= 500) return '576p';
  if (height >= 350) return '480p';
  return '${height}p';
}

String _formatBitrate(int bitrate) {
  final megabits = bitrate / 1000000;
  final value = megabits >= 10 || megabits == megabits.roundToDouble()
      ? megabits.toStringAsFixed(0)
      : megabits.toStringAsFixed(1);
  return '$value Mb/s';
}

String _friendlyError(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  return message.replaceFirst('FormatException: ', '');
}
