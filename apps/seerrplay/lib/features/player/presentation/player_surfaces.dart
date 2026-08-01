part of 'player_screen.dart';

class _CentralPlaybackOverlay extends StatefulWidget {
  const _CentralPlaybackOverlay({
    required this.title,
    required this.controller,
    required this.controlsVisible,
    required this.playbackExpected,
    required this.isCasting,
    required this.castPlaying,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onRewind,
    required this.onForward,
  });

  final String title;
  final VideoPlayerController controller;
  final bool controlsVisible;
  final bool playbackExpected;
  final bool isCasting;
  final bool castPlaying;
  final VoidCallback onBack;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function() onRewind;
  final Future<void> Function() onForward;

  @override
  State<_CentralPlaybackOverlay> createState() =>
      _CentralPlaybackOverlayState();
}

class _CentralPlaybackOverlayState extends State<_CentralPlaybackOverlay> {
  static const _stallDelay = Duration(milliseconds: 350);

  Timer? _timer;
  Duration _lastPosition = Duration.zero;
  DateTime _lastProgressAt = DateTime.now();
  bool _visible = false;
  bool _wasBuffering = false;

  @override
  void initState() {
    super.initState();
    _lastPosition = widget.controller.value.position;
    widget.controller.addListener(_handlePlaybackUpdate);
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _evaluateVisibility(),
    );
  }

  @override
  void didUpdateWidget(covariant _CentralPlaybackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handlePlaybackUpdate);
    _lastPosition = widget.controller.value.position;
    _lastProgressAt = DateTime.now();
    widget.controller.addListener(_handlePlaybackUpdate);
    _setVisible(false);
  }

  void _handlePlaybackUpdate() {
    final value = widget.controller.value;
    if (value.isBuffering && !_wasBuffering) {
      _lastProgressAt = DateTime.now();
    }
    _wasBuffering = value.isBuffering;
    final position = value.position;
    if (position > _lastPosition) {
      _lastProgressAt = DateTime.now();
      _setVisible(false);
    }
    _lastPosition = position;
  }

  void _evaluateVisibility() {
    final value = widget.controller.value;
    final stalled =
        value.isBuffering &&
        widget.playbackExpected &&
        DateTime.now().difference(_lastProgressAt) >= _stallDelay;
    _setVisible(stalled);
  }

  void _setVisible(bool visible) {
    if (_visible == visible || !mounted) return;
    setState(() => _visible = visible);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_handlePlaybackUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;
    if (_visible) {
      return _PlayerLoadingOverlay(
        title: widget.title,
        onBack: widget.onBack,
        backgroundColor: Colors.transparent,
        showHeader: !widget.controlsVisible,
        blockInteraction: false,
      );
    }
    return Center(
      child: widget.controlsVisible
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SkipButton(rewind: true, onPressed: widget.onRewind),
                SizedBox(width: compact ? 22 : 42),
                IconButton.filled(
                  tooltip: context.tr(
                    (widget.isCasting
                            ? widget.castPlaying
                            : widget.controller.value.isPlaying)
                        ? 'Pause'
                        : 'Play state',
                  ),
                  iconSize: compact ? 42 : 52,
                  onPressed: widget.onTogglePlayback,
                  icon: Icon(
                    (widget.isCasting
                            ? widget.castPlaying
                            : widget.controller.value.isPlaying)
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                SizedBox(width: compact ? 22 : 42),
                _SkipButton(rewind: false, onPressed: widget.onForward),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _PlayerLoadingOverlay extends StatelessWidget {
  const _PlayerLoadingOverlay({
    required this.title,
    required this.onBack,
    this.backgroundColor = Colors.black,
    this.showHeader = true,
    this.blockInteraction = true,
  });

  final String title;
  final VoidCallback onBack;
  final Color backgroundColor;
  final bool showHeader;
  final bool blockInteraction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (blockInteraction)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ColoredBox(color: backgroundColor),
          )
        else if (backgroundColor != Colors.transparent)
          IgnorePointer(child: ColoredBox(color: backgroundColor)),
        const IgnorePointer(
          child: Center(
            child: SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
        if (showHeader)
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
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
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FittedVideo extends StatelessWidget {
  const _FittedVideo({required this.controller, required this.fit});

  final VideoPlayerController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = controller.value.aspectRatio;
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: aspectRatio * 1000,
          height: 1000,
          child: VideoPlayer(
            controller,
            key: ValueKey<int>(controller.playerId),
          ),
        ),
      ),
    );
  }
}

class _SubtitleOverlay extends StatefulWidget {
  const _SubtitleOverlay({
    required this.controller,
    required this.cues,
    required this.preferences,
    required this.controlsVisible,
  });

  final VideoPlayerController controller;
  final List<SubtitleCue> cues;
  final SubtitleStylePreferences preferences;
  final bool controlsVisible;

  @override
  State<_SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<_SubtitleOverlay> {
  String? _text;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateCue);
    _updateCue();
  }

  @override
  void didUpdateWidget(covariant _SubtitleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_updateCue);
      widget.controller.addListener(_updateCue);
    }
    if (oldWidget.cues != widget.cues) _updateCue();
  }

  void _updateCue() {
    final position = widget.controller.value.position;
    var low = 0;
    var high = widget.cues.length - 1;
    SubtitleCue? active;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final cue = widget.cues[middle];
      if (position < cue.start) {
        high = middle - 1;
      } else if (position > cue.end) {
        low = middle + 1;
      } else {
        active = cue;
        break;
      }
    }
    final text = active?.text;
    if (text != _text && mounted) setState(() => _text = text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateCue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    final compact = MediaQuery.sizeOf(context).width < 700;
    final baseSize = compact ? 20.0 : 28.0;
    return IgnorePointer(
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            widget.controlsVisible ? (compact ? 92 : 118) : 26,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.preferences.background.color,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.preferences.color.color,
                    fontSize: baseSize * widget.preferences.size.scale,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 3),
                      Shadow(color: Colors.black, offset: Offset(1, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AirPlayPlaybackSurface extends StatelessWidget {
  const _AirPlayPlaybackSurface({this.deviceName});

  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.airplay_rounded, size: 58, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                context.tr('Playing with AirPlay'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (deviceName != null) ...[
                const SizedBox(height: 6),
                Text(
                  deviceName!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                context.tr(
                  'Use the AirPlay button to change or stop playback on the TV.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
