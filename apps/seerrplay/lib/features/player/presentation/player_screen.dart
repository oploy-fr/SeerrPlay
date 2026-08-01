import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/player/domain/subtitle_cue.dart';
import 'package:seerrplay/features/player/domain/subtitle_style_preferences.dart';
import 'package:seerrplay/features/player/presentation/native_route_button.dart';
import 'package:video_player/video_player.dart' show VideoViewType;
import 'package:video_player_pip/index.dart';

const _windowControlChannel = MethodChannel('app.seerrplay/window');

@visibleForTesting
bool shouldStartAutomaticPip(AppLifecycleState state) {
  return state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    required this.media,
    this.startFromBeginning = false,
    super.key,
  });

  final MediaViewModel media;
  final bool startFromBeginning;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  MediaServerClient? _client;
  MediaServerSource? _source;
  String? _playSessionId;
  String? _playingItemId;
  Uri? _playbackUri;
  Timer? _progressTimer;
  Timer? _controlsTimer;
  String? _error;
  bool _controlsVisible = true;
  bool _changingStream = false;
  bool _playbackRequested = true;
  bool _isInPipMode = false;
  bool _enteringPipMode = false;
  bool _isFullscreen = supportsMobileSystemUi;
  StreamSubscription<bool>? _pipSubscription;
  int? _audioStreamIndex;
  int? _subtitleStreamIndex;
  List<SubtitleCue> _subtitleCues = const [];
  bool _subtitleRenderedByServer = false;
  int _subtitleLoadGeneration = 0;
  SubtitleStylePreferences _subtitleStyle = const SubtitleStylePreferences();
  int? _maxStreamingBitrate;
  double _volume = 1;
  double _playbackSpeed = 1;
  bool _volumeExpanded = false;
  _PlayerFit _playerFit = _PlayerFit.cover;
  Duration? _queuedSeekPosition;
  Duration? _seekAnchor;
  Future<void>? _activeSeek;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (supportsMobileSystemUi) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    if (supportsSystemPictureInPicture) {
      _pipSubscription = VideoPlayerPip.instance.onPipModeChanged.listen((
        active,
      ) {
        if (mounted) setState(() => _isInPipMode = active);
      });
    }
    nativeCastController.addListener(_handleCastState);
    if (isDesktopPlatform) unawaited(_loadFullscreenState());
    unawaited(_loadSubtitleStyle());
    _initialize();
  }

  Future<void> _loadSubtitleStyle() async {
    final style = await SubtitleStylePreferences.load();
    if (mounted) setState(() => _subtitleStyle = style);
  }

  Future<void> _loadFullscreenState() async {
    try {
      final fullscreen =
          await _windowControlChannel.invokeMethod<bool>('isFullscreen') ??
          false;
      if (mounted) setState(() => _isFullscreen = fullscreen);
    } on MissingPluginException {
      // The desktop runner may not expose window controls on every platform.
    }
  }

  Future<void> _toggleFullscreen() async {
    _showControls();
    if (isDesktopPlatform) {
      try {
        final fullscreen =
            await _windowControlChannel.invokeMethod<bool>(
              'toggleFullscreen',
            ) ??
            !_isFullscreen;
        if (mounted) setState(() => _isFullscreen = fullscreen);
      } on MissingPluginException {
        // Keep playback usable when a desktop runner has no window channel.
      }
      return;
    }

    final fullscreen = !_isFullscreen;
    await SystemChrome.setEnabledSystemUIMode(
      fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) setState(() => _isFullscreen = fullscreen);
  }

  Future<void> _initialize() async {
    final localFilePath = widget.media.localFilePath;
    if (localFilePath != null) {
      await _initializeLocalFile(localFilePath);
      return;
    }
    final itemId = widget.media.mediaServerItemId;
    if (itemId == null) {
      setState(
        () => _error = context.tr(
          'This media is not linked to the media server.',
        ),
      );
      return;
    }
    try {
      final client = ref.read(mediaServerClientProvider);
      final item = await client.getPlayableItem(itemId);
      final startTicks = widget.startFromBeginning
          ? 0
          : item.userData?.playbackPositionTicks ?? 0;
      _client = client;
      _playingItemId = item.id;
      await _openStream(startTicks: startTicks, initialLoad: true);
      _progressTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _reportProgress(),
      );
      _scheduleControlsHide();
    } catch (error, stackTrace) {
      debugPrint('Offline playback initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _initializeLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const FormatException('The downloaded file is unavailable.');
      }
      final controller = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: true,
        ),
        viewType: VideoViewType.platformView,
      );
      await controller.initialize();
      await controller.setVolume(_volume);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
      unawaited(_prepareAutomaticPip(controller));
      _scheduleControlsHide();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<bool> _openStream({
    required int startTicks,
    bool initialLoad = false,
  }) async {
    final client = _client;
    final itemId = _playingItemId;
    if (client == null || itemId == null) return false;

    final oldController = _controller;
    VideoPlayerController? pendingController;
    final resumePlayback = oldController?.value.isPlaying ?? true;
    if (!initialLoad) {
      if (supportsSystemPictureInPicture) {
        unawaited(VideoPlayerPip.disableAutomaticPip());
      }
      _controlsTimer?.cancel();
      if (mounted) {
        setState(() {
          _changingStream = true;
          _controlsVisible = false;
        });
      }
      await oldController?.pause();
    }
    final oldValues = _reportValues;
    if (oldValues != null) await _reportStopped(oldValues);

    try {
      // Track and quality changes may require a new transcoding session. Keep
      // the old controller alive until the replacement renders successfully;
      // this also gives us a working stream to restore when negotiation fails.
      final forceTranscoding =
          !initialLoad &&
          ((_subtitleRenderedByServer && _subtitleStreamIndex != null) ||
              _audioStreamIndex != _source?.defaultAudioStreamIndex ||
              _maxStreamingBitrate != null);
      final playback = await client.getPlaybackInfo(
        itemId,
        startTimeTicks: startTicks,
        audioStreamIndex: initialLoad ? null : _audioStreamIndex,
        subtitleStreamIndex:
            _subtitleRenderedByServer && _subtitleStreamIndex != null
            ? _subtitleStreamIndex
            : -1,
        maxStreamingBitrate: _maxStreamingBitrate,
        forceTranscoding: forceTranscoding,
      );
      if (playback.mediaSources.isEmpty) {
        throw const FormatException('No video source available.');
      }
      final source = playback.mediaSources.first;
      if (initialLoad) {
        _audioStreamIndex =
            source.defaultAudioStreamIndex ??
            source.audioStreams
                .where((stream) => stream.isDefault)
                .firstOrNull
                ?.index ??
            source.audioStreams.firstOrNull?.index;
        _subtitleStreamIndex = source.defaultSubtitleStreamIndex;
        _subtitleStreamIndex ??= source.subtitleStreams
            .where((stream) => stream.isDefault)
            .firstOrNull
            ?.index;
      }
      final playbackUri = client.playbackUri(itemId, source);
      final controller = VideoPlayerController.networkUrl(
        playbackUri,
        httpHeaders: client.playbackHeaders(),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: true,
        ),
        viewType: VideoViewType.platformView,
      );
      pendingController = controller;
      await controller.initialize();
      await controller.setVolume(_volume);
      await controller.setPlaybackSpeed(_playbackSpeed);
      if (startTicks > 0) {
        final resumeAt = Duration(microseconds: startTicks ~/ 10);
        final safePosition = resumeAt < controller.value.duration
            ? resumeAt
            : Duration.zero;
        await controller.seekTo(safePosition);
      }
      if (resumePlayback && !nativeCastController.connected) {
        await controller.play();
      }
      if (!mounted) {
        await controller.dispose();
        return false;
      }
      setState(() {
        _source = source;
        _playSessionId = playback.playSessionId ?? '';
        _playbackUri = playbackUri;
        _controller = controller;
        _changingStream = false;
        _controlsVisible = true;
        _error = null;
      });
      unawaited(_prepareAutomaticPip(controller));
      pendingController = null;
      // Platform views are swapped by the native compositor. Disposing the old
      // controller before the next frame can leave a valid stream audio-only.
      await WidgetsBinding.instance.endOfFrame;
      await oldController?.dispose();
      await _reportStarted();
      if (initialLoad && _subtitleStreamIndex != null) {
        unawaited(
          _activateSubtitle(_subtitleStreamIndex!, allowFallback: true),
        );
      }
      _scheduleControlsHide();
      return true;
    } catch (error, stackTrace) {
      debugPrint('Media server playback initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await pendingController?.dispose();
      if (!initialLoad && resumePlayback) {
        await oldController?.play();
      }
      if (mounted) {
        setState(() {
          _changingStream = false;
          _controlsVisible = true;
          _error = _friendlyError(error);
        });
      }
      if (!initialLoad && oldValues != null) await _reportStarted();
      _scheduleControlsHide();
      return false;
    }
  }

  Future<void> _enterPictureInPicture() async {
    if (!supportsSystemPictureInPicture) return;
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _enteringPipMode ||
        _changingStream ||
        nativeCastController.connected ||
        nativeCastController.airPlayConnected ||
        nativeCastController.airPlayRoutePickerVisible) {
      return;
    }
    _enteringPipMode = true;
    try {
      final ratio = controller.value.aspectRatio;
      final width = 360;
      final height = ratio > 0 ? (width / ratio).round() : 203;
      final entered = await VideoPlayerPip.enterPipMode(
        controller,
        width: width,
        height: height,
      );
      if (mounted && entered) setState(() => _isInPipMode = true);
    } on PlatformException {
      if (mounted) setState(() => _isInPipMode = false);
    } finally {
      _enteringPipMode = false;
    }
  }

  Future<void> _prepareAutomaticPip(VideoPlayerController controller) async {
    if (!supportsSystemPictureInPicture ||
        !controller.value.isInitialized ||
        nativeCastController.connected) {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        !identical(_controller, controller) ||
        !controller.value.isPlaying) {
      return;
    }
    final ratio = controller.value.aspectRatio;
    const width = 360;
    final height = ratio > 0 ? (width / ratio).round() : 203;
    await VideoPlayerPip.prepareAutomaticPip(
      controller,
      width: width,
      height: height,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (supportsSystemPictureInPicture &&
        shouldStartAutomaticPip(state) &&
        _controller?.value.isPlaying == true &&
        !_isInPipMode &&
        !nativeCastController.airPlayRoutePickerVisible &&
        !nativeCastController.airPlayConnected) {
      unawaited(_enterPictureInPicture());
    }
  }

  int get _positionTicks =>
      (_controller?.value.position.inMicroseconds ?? 0) * 10;

  Future<void> _reportStarted() async {
    final values = _reportValues;
    if (values == null) return;
    await values.client.reportPlaybackStarted(
      itemId: values.itemId,
      mediaSourceId: values.source.id,
      playSessionId: values.playSessionId,
      positionTicks: _positionTicks,
      audioStreamIndex: _audioStreamIndex,
      subtitleStreamIndex: _subtitleStreamIndex,
      playMethod: values.source.playMethod,
    );
  }

  Future<void> _reportProgress() async {
    final values = _reportValues;
    final controller = _controller;
    if (values == null || controller == null) return;
    await values.client.reportPlaybackProgress(
      itemId: values.itemId,
      mediaSourceId: values.source.id,
      playSessionId: values.playSessionId,
      positionTicks: _positionTicks,
      isPaused: !controller.value.isPlaying,
      audioStreamIndex: _audioStreamIndex,
      subtitleStreamIndex: _subtitleStreamIndex,
      volumeLevel: (_volume * 100).round(),
      playMethod: values.source.playMethod,
    );
  }

  Future<void> _reportStopped(_PlaybackReportValues values) {
    return values.client.reportPlaybackStopped(
      itemId: values.itemId,
      mediaSourceId: values.source.id,
      playSessionId: values.playSessionId,
      positionTicks: _positionTicks,
      audioStreamIndex: _audioStreamIndex,
      subtitleStreamIndex: _subtitleStreamIndex,
      playMethod: values.source.playMethod,
    );
  }

  _PlaybackReportValues? get _reportValues {
    final client = _client;
    final itemId = _playingItemId;
    final source = _source;
    final session = _playSessionId;
    if (client == null || itemId == null || source == null || session == null) {
      return null;
    }
    return _PlaybackReportValues(
      client: client,
      itemId: itemId,
      source: source,
      playSessionId: session,
    );
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (nativeCastController.connected) {
      nativeCastController.playing
          ? await nativeCastController.pause()
          : await nativeCastController.play();
      _showControls();
      return;
    }
    if (controller.value.isPlaying) {
      _playbackRequested = false;
      await controller.pause();
      if (supportsSystemPictureInPicture) {
        unawaited(VideoPlayerPip.disableAutomaticPip());
      }
      _controlsTimer?.cancel();
    } else {
      _playbackRequested = true;
      await controller.play();
      unawaited(_prepareAutomaticPip(controller));
      _scheduleControlsHide();
    }
    if (mounted) setState(() {});
    unawaited(_reportProgress());
  }

  Future<void> _seekRelative(Duration delta) async {
    final controller = _controller;
    if (controller == null) return;
    final base =
        _queuedSeekPosition ?? _seekAnchor ?? controller.value.position;
    await _requestSeek(base + delta);
  }

  Future<void> _requestSeek(Duration requested) {
    final controller = _controller;
    if (controller == null) return Future.value();
    final duration = controller.value.duration;
    final position = requested < Duration.zero
        ? Duration.zero
        : requested > duration
        ? duration
        : requested;
    _queuedSeekPosition = position;
    _seekAnchor = position;
    final active = _activeSeek;
    if (active != null) return active;

    late final Future<void> operation;
    operation = _drainSeekQueue().whenComplete(() {
      if (identical(_activeSeek, operation)) {
        _activeSeek = null;
        if (_queuedSeekPosition == null) {
          _seekAnchor = null;
        } else {
          unawaited(_requestSeek(_queuedSeekPosition!));
        }
      }
    });
    _activeSeek = operation;
    return operation;
  }

  Future<void> _drainSeekQueue() async {
    while (_queuedSeekPosition != null) {
      final position = _queuedSeekPosition!;
      _queuedSeekPosition = null;
      final controller = _controller;
      if (controller == null) return;
      if (nativeCastController.connected) {
        await nativeCastController.seek(position);
      }
      await controller.seekTo(position);
    }
    _showControls();
    unawaited(_reportProgress());
  }

  Future<void> _setVolume(double value) async {
    _volume = value;
    await _controller?.setVolume(value);
    await nativeCastController.setVolume(value);
    if (mounted) setState(() {});
  }

  Future<void> _changeStream({
    int? audioIndex,
    int? subtitleIndex,
    int? bitrate,
    bool changeAudio = false,
    bool changeSubtitle = false,
    bool changeQuality = false,
  }) async {
    if (_changingStream) return;
    final position = _positionTicks;
    final previousAudioIndex = _audioStreamIndex;
    final previousSubtitleIndex = _subtitleStreamIndex;
    final previousBitrate = _maxStreamingBitrate;
    if (changeAudio) _audioStreamIndex = audioIndex;
    if (changeSubtitle) _subtitleStreamIndex = subtitleIndex;
    if (changeQuality) _maxStreamingBitrate = bitrate;
    if (mounted) setState(() {});
    final changed = await _openStream(startTicks: position);
    if (!changed) {
      _audioStreamIndex = previousAudioIndex;
      _subtitleStreamIndex = previousSubtitleIndex;
      _maxStreamingBitrate = previousBitrate;
      if (mounted) setState(() {});
    }
  }

  Future<void> _activateSubtitle(
    int? index, {
    bool allowFallback = true,
  }) async {
    final generation = ++_subtitleLoadGeneration;
    final source = _source;
    final client = _client;
    final itemId = _playingItemId;
    final wasRenderedByServer = _subtitleRenderedByServer;
    _subtitleStreamIndex = index;
    _subtitleCues = const [];
    _subtitleRenderedByServer = false;
    if (mounted) setState(() {});

    if (index == null || source == null || client == null || itemId == null) {
      if (wasRenderedByServer) await _openStream(startTicks: _positionTicks);
      return;
    }

    final stream = source.subtitleStreams
        .where((candidate) => candidate.index == index)
        .firstOrNull;
    if (stream != null) {
      try {
        final text = await client.fetchSubtitleText(itemId, source, stream);
        final cues = text == null
            ? const <SubtitleCue>[]
            : parseSubtitleCues(text);
        if (generation != _subtitleLoadGeneration) return;
        if (cues.isNotEmpty) {
          _subtitleCues = cues;
          if (mounted) setState(() {});
          if (wasRenderedByServer) {
            await _openStream(startTicks: _positionTicks);
          }
          return;
        }
      } catch (error) {
        debugPrint('Client subtitle loading failed: $error');
      }
    }

    if (generation != _subtitleLoadGeneration) return;
    if (!allowFallback) return;
    _subtitleRenderedByServer = true;
    if (mounted) setState(() {});
    await _openStream(startTicks: _positionTicks);
  }

  void _handleCastState() {
    if (!mounted) return;
    if (nativeCastController.connected) {
      if (supportsSystemPictureInPicture) {
        unawaited(VideoPlayerPip.disableAutomaticPip());
      }
      final controller = _controller;
      if (controller?.value.isPlaying == true) unawaited(controller!.pause());
      final castPosition = nativeCastController.position;
      if (controller != null &&
          (controller.value.position - castPosition).abs() >
              const Duration(seconds: 2)) {
        unawaited(controller.seekTo(castPosition));
      }
    }
    setState(() {});
  }

  Future<void> _showSettings() async {
    _controlsTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16171C),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PlayerSettingsSheet(
        source: _source,
        serverName: _client?.serverType.displayName ?? 'Media server',
        videoSize: _controller?.value.size,
        selectedAudioIndex: _audioStreamIndex,
        selectedSubtitleIndex: _subtitleStreamIndex,
        maxStreamingBitrate: _maxStreamingBitrate,
        playbackSpeed: _playbackSpeed,
        playerFit: _playerFit,
        onAudioChanged: (index) async {
          Navigator.of(context).pop();
          await _changeStream(audioIndex: index, changeAudio: true);
        },
        onSubtitleChanged: (index) async {
          Navigator.of(context).pop();
          await _activateSubtitle(index);
        },
        onQualityChanged: (bitrate) async {
          Navigator.of(context).pop();
          await _changeStream(bitrate: bitrate, changeQuality: true);
        },
        onSpeedChanged: (speed) async {
          _playbackSpeed = speed;
          await _controller?.setPlaybackSpeed(speed);
          if (mounted) setState(() {});
        },
        onFitChanged: (fit) {
          setState(() => _playerFit = fit);
        },
      ),
    );
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pipSubscription?.cancel());
    _progressTimer?.cancel();
    _controlsTimer?.cancel();
    nativeCastController.removeListener(_handleCastState);
    if (supportsSystemPictureInPicture) {
      unawaited(VideoPlayerPip.disableAutomaticPip());
    }
    final values = _reportValues;
    if (values != null) unawaited(_reportStopped(values));
    _controller?.dispose();
    _restoreMobileSystemUi();
    super.dispose();
  }

  void _restoreMobileSystemUi() {
    if (!supportsMobileSystemUi) return;
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      onPopInvokedWithResult: (_, _) {
        _restoreMobileSystemUi();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _error != null && controller == null
            ? _PlayerError(message: _error!, onRetry: _initialize)
            : controller == null
            ? _PlayerLoadingOverlay(
                title: widget.media.title,
                onBack: () => Navigator.of(context).pop(),
              )
            : CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.space): () =>
                      unawaited(_togglePlayback()),
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                      unawaited(_seekRelative(const Duration(seconds: -10))),
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                      unawaited(_seekRelative(const Duration(seconds: 10))),
                  const SingleActivator(LogicalKeyboardKey.keyM): () =>
                      unawaited(_setVolume(_volume > 0 ? 0 : 1)),
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    if (_isFullscreen) {
                      unawaited(_toggleFullscreen());
                      return;
                    }
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                },
                child: Focus(
                  autofocus: true,
                  child: MouseRegion(
                    cursor: _controlsVisible
                        ? MouseCursor.defer
                        : SystemMouseCursors.none,
                    onHover: (_) => _showControls(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_controlsVisible) {
                          _controlsTimer?.cancel();
                          setState(() => _controlsVisible = false);
                        } else {
                          _showControls();
                        }
                      },
                      onDoubleTapDown: (details) {
                        final width = MediaQuery.sizeOf(context).width;
                        unawaited(
                          _seekRelative(
                            details.localPosition.dx < width / 2
                                ? const Duration(seconds: -10)
                                : const Duration(seconds: 10),
                          ),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (nativeCastController.airPlayConnected)
                            _AirPlayPlaybackSurface(
                              deviceName:
                                  nativeCastController.airPlayDeviceName,
                            )
                          else
                            _FittedVideo(
                              controller: controller,
                              fit: _playerFit.fit,
                            ),
                          if (!nativeCastController.airPlayConnected &&
                              !nativeCastController.connected &&
                              _subtitleCues.isNotEmpty)
                            _SubtitleOverlay(
                              controller: controller,
                              cues: _subtitleCues,
                              preferences: _subtitleStyle,
                              controlsVisible: _controlsVisible,
                            ),
                          if (_controlsVisible &&
                              !_changingStream &&
                              !_isInPipMode)
                            _PlayerControls(
                              title: widget.media.title,
                              controller: controller,
                              volume: _volume,
                              onInteraction: _showControls,
                              onBack: () => Navigator.of(context).pop(),
                              onSeek: _requestSeek,
                              onVolumeChanged: _setVolume,
                              volumeExpanded: _volumeExpanded,
                              onToggleVolumePanel: () => setState(
                                () => _volumeExpanded = !_volumeExpanded,
                              ),
                              onSettings: _showSettings,
                              isFullscreen: _isFullscreen,
                              onToggleFullscreen: _toggleFullscreen,
                              routeButton: _playbackUri == null
                                  ? null
                                  : NativeRouteButton(
                                      streamUrl: _playbackUri.toString(),
                                      title: widget.media.title,
                                      contentType:
                                          _source?.transcodingUrl != null
                                          ? 'application/x-mpegURL'
                                          : 'video/${_source?.container ?? 'mp4'}',
                                      position: controller.value.position,
                                    ),
                              isCasting: nativeCastController.connected,
                              castDeviceName: nativeCastController.deviceName,
                              airPlayDeviceName:
                                  nativeCastController.airPlayConnected
                                  ? nativeCastController.airPlayDeviceName
                                  : null,
                            ),
                          if (!_changingStream && !_isInPipMode)
                            _CentralPlaybackOverlay(
                              title: widget.media.title,
                              controller: controller,
                              controlsVisible: _controlsVisible,
                              playbackExpected:
                                  _playbackRequested &&
                                  !nativeCastController.connected,
                              isCasting: nativeCastController.connected,
                              castPlaying: nativeCastController.playing,
                              onBack: () => Navigator.of(context).pop(),
                              onTogglePlayback: _togglePlayback,
                              onRewind: () =>
                                  _seekRelative(const Duration(seconds: -10)),
                              onForward: () =>
                                  _seekRelative(const Duration(seconds: 10)),
                            ),
                          if (_changingStream)
                            Positioned.fill(
                              child: _PlayerLoadingOverlay(
                                title: widget.media.title,
                                backgroundColor: const Color(0xCC000000),
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
                          if (_error != null)
                            Positioned(
                              left: 24,
                              right: 24,
                              bottom: 88,
                              child: Material(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    context.tr(_error!),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _PlaybackReportValues {
  const _PlaybackReportValues({
    required this.client,
    required this.itemId,
    required this.source,
    required this.playSessionId,
  });

  final MediaServerClient client;
  final String itemId;
  final MediaServerSource source;
  final String playSessionId;
}

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
