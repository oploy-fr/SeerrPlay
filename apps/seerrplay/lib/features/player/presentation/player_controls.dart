part of 'player_screen.dart';

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.title,
    required this.controller,
    required this.volume,
    required this.onInteraction,
    required this.onBack,
    required this.onSeek,
    required this.onVolumeChanged,
    required this.volumeExpanded,
    required this.onToggleVolumePanel,
    required this.onSettings,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.isCasting,
    this.castDeviceName,
    this.airPlayDeviceName,
    this.routeButton,
  });

  final String title;
  final VideoPlayerController controller;
  final double volume;
  final VoidCallback onInteraction;
  final VoidCallback onBack;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function(double) onVolumeChanged;
  final bool volumeExpanded;
  final VoidCallback onToggleVolumePanel;
  final VoidCallback onSettings;
  final bool isFullscreen;
  final Future<void> Function() onToggleFullscreen;
  final bool isCasting;
  final String? castDeviceName;
  final String? airPlayDeviceName;
  final Widget? routeButton;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final compact = MediaQuery.sizeOf(context).width < 650;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent, Colors.black87],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: context.tr('Back'),
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (isCasting)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            castDeviceName ?? 'Chromecast',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      if (airPlayDeviceName != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'AirPlay · $airPlayDeviceName',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      IconButton(
                        tooltip: context.tr(
                          volumeExpanded ? 'Hide volume' : 'Volume',
                        ),
                        onPressed: onToggleVolumePanel,
                        icon: Icon(
                          volume == 0
                              ? Icons.volume_off_rounded
                              : volume < 0.5
                              ? Icons.volume_down_rounded
                              : Icons.volume_up_rounded,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: volumeExpanded ? (compact ? 92 : 150) : 0,
                        child: ClipRect(
                          child: Slider(
                            value: volume,
                            onChanged: volumeExpanded
                                ? (value) {
                                    onInteraction();
                                    unawaited(onVolumeChanged(value));
                                  }
                                : null,
                          ),
                        ),
                      ),
                      ?routeButton,
                      IconButton(
                        tooltip: context.tr('Playback settings'),
                        onPressed: onSettings,
                        icon: const Icon(Icons.settings_rounded),
                      ),
                      IconButton(
                        tooltip: context.tr(
                          isFullscreen
                              ? 'Exit full screen'
                              : 'Enter full screen',
                        ),
                        onPressed: () {
                          onInteraction();
                          unawaited(onToggleFullscreen());
                        },
                        icon: Icon(
                          isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _PlaybackTimeline(
                  controller: controller,
                  onInteraction: onInteraction,
                  onSeek: onSeek,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlaybackTimeline extends StatefulWidget {
  const _PlaybackTimeline({
    required this.controller,
    required this.onInteraction,
    required this.onSeek,
  });

  final VideoPlayerController controller;
  final VoidCallback onInteraction;
  final Future<void> Function(Duration) onSeek;

  @override
  State<_PlaybackTimeline> createState() => _PlaybackTimelineState();
}

class _PlaybackTimelineState extends State<_PlaybackTimeline> {
  Duration? _scrubPosition;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final value = widget.controller.value;
        final duration = value.duration;
        final controllerPosition = value.position > duration
            ? duration
            : value.position;
        final position = _scrubPosition ?? controllerPosition;
        final remaining = duration - position;
        final bufferedPosition = value.buffered.isEmpty
            ? controllerPosition
            : value.buffered.last.end;
        final bufferedMilliseconds = bufferedPosition.inMilliseconds
            .clamp(controllerPosition.inMilliseconds, duration.inMilliseconds)
            .toDouble();
        final maximum = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final timeWidth = duration.inHours >= 10
            ? 88.0
            : duration.inHours > 0
            ? 76.0
            : 56.0;
        const timeStyle = TextStyle(
          fontFeatures: [FontFeature.tabularFigures()],
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              SizedBox(
                width: timeWidth,
                child: Text(
                  _formatDuration(position),
                  style: timeStyle,
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    secondaryActiveTrackColor: Colors.white38,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 13,
                    ),
                  ),
                  child: Slider(
                    value: position.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble(),
                    secondaryTrackValue: bufferedMilliseconds,
                    max: maximum,
                    onChangeStart: (milliseconds) {
                      widget.onInteraction();
                      setState(
                        () => _scrubPosition = Duration(
                          milliseconds: milliseconds.round(),
                        ),
                      );
                    },
                    onChanged: (milliseconds) {
                      widget.onInteraction();
                      setState(
                        () => _scrubPosition = Duration(
                          milliseconds: milliseconds.round(),
                        ),
                      );
                    },
                    onChangeEnd: (milliseconds) async {
                      final target = Duration(
                        milliseconds: milliseconds.round(),
                      );
                      setState(() => _scrubPosition = target);
                      await widget.onSeek(target);
                      if (mounted) setState(() => _scrubPosition = null);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: timeWidth,
                child: Text(
                  '-${_formatDuration(remaining)}',
                  style: timeStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.rewind, required this.onPressed});

  final bool rewind;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr(rewind ? 'Rewind 10 seconds' : 'Forward 10 seconds'),
    iconSize: 42,
    onPressed: onPressed,
    icon: Icon(rewind ? Icons.replay_10_rounded : Icons.forward_10_rounded),
  );
}
