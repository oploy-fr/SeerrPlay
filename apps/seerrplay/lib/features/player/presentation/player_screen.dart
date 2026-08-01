import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';
import 'package:seerrplay/core/platform/platform_capabilities.dart';
import 'package:seerrplay/features/auth/application/app_session_controller.dart';
import 'package:seerrplay/features/auth/application/client_providers.dart';
import 'package:seerrplay/features/media_server/domain/media_server_models.dart';
import 'package:seerrplay/features/media/domain/media_view_model.dart';
import 'package:seerrplay/features/media_server/data/media_server_client.dart';
import 'package:seerrplay/features/player/domain/subtitle_cue.dart';
import 'package:seerrplay/features/player/domain/subtitle_style_preferences.dart';
import 'package:seerrplay/features/player/application/playback_position_store.dart';
import 'package:seerrplay/features/player/presentation/native_route_button.dart';
import 'package:video_player/video_player.dart' show VideoViewType;
import 'package:video_player_pip/index.dart';

part 'player_controls.dart';
part 'player_settings.dart';
part 'player_surfaces.dart';

const _windowControlChannel = MethodChannel('app.seerrplay/window');

@visibleForTesting
bool shouldStartAutomaticPip(AppLifecycleState state) {
  return state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
}

@visibleForTesting
int latestResumeTicks(int serverTicks, int savedTicks) =>
    serverTicks > savedTicks ? serverTicks : savedTicks;

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
  final PlaybackPositionStore _positionStore = const PlaybackPositionStore();
  bool _wasAirPlayConnected = false;
  bool _wasAirPlayRoutePickerVisible = false;
  bool _airPlayStreamPrepared = false;
  bool _switchingToAirPlayStream = false;

  String get _resumeMediaKey {
    final profileId = ref
        .read(appSessionControllerProvider)
        .requireValue
        .profile!
        .id;
    return '$profileId:${widget.media.mediaServerItemId ?? widget.media.id}';
  }

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
      await _initializeDownloadedFile(localFilePath);
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
      final savedTicks = await _positionStore.loadTicks(_resumeMediaKey);
      final startTicks = widget.startFromBeginning
          ? 0
          : latestResumeTicks(
              item.userData?.playbackPositionTicks ?? 0,
              savedTicks,
            );
      if (widget.startFromBeginning) {
        await _positionStore.clear(_resumeMediaKey);
      }
      _client = client;
      _playingItemId = item.id;
      await _openStream(startTicks: startTicks, initialLoad: true);
      _progressTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(_reportProgress()),
      );
      _scheduleControlsHide();
    } catch (error, stackTrace) {
      debugPrint('Offline playback initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  Future<void> _initializeDownloadedFile(String filePath) async {
    var startTicks = widget.startFromBeginning
        ? 0
        : await _positionStore.loadTicks(_resumeMediaKey);
    if (widget.startFromBeginning) {
      await _positionStore.clear(_resumeMediaKey);
    }
    final itemId = widget.media.mediaServerItemId;
    if (itemId != null) {
      try {
        final client = ref.read(mediaServerClientProvider);
        final item = await client.getPlayableItem(itemId);
        if (!widget.startFromBeginning) {
          startTicks = latestResumeTicks(
            item.userData?.playbackPositionTicks ?? 0,
            startTicks,
          );
        }
        final playback = await client.getPlaybackInfo(
          item.id,
          startTimeTicks: startTicks,
        );
        final source = playback.mediaSources.firstOrNull;
        if (source != null) {
          _client = client;
          _playingItemId = item.id;
          _source = source;
          _playSessionId = playback.playSessionId ?? '';
        }
      } catch (_) {
        // Offline playback remains available without the media server.
      }
    }
    await _initializeLocalFile(filePath, startTicks: startTicks);
    if (_reportValues != null) {
      await _reportStarted();
      _progressTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(_reportProgress()),
      );
    }
  }

  Future<void> _initializeLocalFile(
    String filePath, {
    required int startTicks,
  }) async {
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
      if (startTicks > 0) {
        final resumeAt = Duration(microseconds: startTicks ~/ 10);
        if (resumeAt < controller.value.duration) {
          await controller.seekTo(resumeAt);
        }
      }
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
    bool forceCompatiblePlayback = false,
    bool omitPlaybackHeaders = false,
  }) async {
    final client = _client;
    final itemId = _playingItemId;
    if (client == null || itemId == null) return false;

    final oldController = _controller;
    VideoPlayerController? pendingController;
    final resumePlayback =
        forceCompatiblePlayback || (oldController?.value.isPlaying ?? true);
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
          forceCompatiblePlayback ||
          (!initialLoad &&
              ((_subtitleRenderedByServer && _subtitleStreamIndex != null) ||
                  _audioStreamIndex != _source?.defaultAudioStreamIndex ||
                  _maxStreamingBitrate != null));
      final requestedMediaSourceId = initialLoad ? null : _source?.id;
      final playback = await client.getPlaybackInfo(
        itemId,
        startTimeTicks: startTicks,
        mediaSourceId: requestedMediaSourceId,
        audioStreamIndex: initialLoad ? null : _audioStreamIndex,
        subtitleStreamIndex:
            _subtitleRenderedByServer && _subtitleStreamIndex != null
            ? _subtitleStreamIndex
            : -1,
        maxStreamingBitrate: _maxStreamingBitrate,
        forceTranscoding: forceTranscoding,
      );
      final source = playback.preferredSource(requestedMediaSourceId);
      if (source == null) {
        throw const FormatException('No video source available.');
      }
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
        // AirPlay fetches the media from the receiver. Jellyfin and Plex put
        // their access token in the URL, while custom AVAsset headers cannot
        // reliably be handed off to an Apple TV.
        httpHeaders: omitPlaybackHeaders
            ? const <String, String>{}
            : client.playbackHeaders(),
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
    await _runPlaybackReport(
      'started',
      () => values.client.reportPlaybackStarted(
        itemId: values.itemId,
        mediaSourceId: values.source.id,
        playSessionId: values.playSessionId,
        positionTicks: _positionTicks,
        audioStreamIndex: _audioStreamIndex,
        subtitleStreamIndex: _subtitleStreamIndex,
        playMethod: values.source.playMethod,
      ),
    );
  }

  Future<void> _reportProgress() async {
    await _saveResumePosition();
    final values = _reportValues;
    final controller = _controller;
    if (values == null || controller == null) return;
    await _runPlaybackReport(
      'progress',
      () => values.client.reportPlaybackProgress(
        itemId: values.itemId,
        mediaSourceId: values.source.id,
        playSessionId: values.playSessionId,
        positionTicks: _positionTicks,
        isPaused: !controller.value.isPlaying,
        audioStreamIndex: _audioStreamIndex,
        subtitleStreamIndex: _subtitleStreamIndex,
        volumeLevel: (_volume * 100).round(),
        playMethod: values.source.playMethod,
      ),
    );
  }

  Future<void> _saveResumePosition() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await _positionStore.save(
      mediaKey: _resumeMediaKey,
      position: controller.value.position,
      duration: controller.value.duration,
    );
  }

  Future<void> _reportStopped(_PlaybackReportValues values) {
    return _runPlaybackReport(
      'stopped',
      () => values.client.reportPlaybackStopped(
        itemId: values.itemId,
        mediaSourceId: values.source.id,
        playSessionId: values.playSessionId,
        positionTicks: _positionTicks,
        audioStreamIndex: _audioStreamIndex,
        subtitleStreamIndex: _subtitleStreamIndex,
        playMethod: values.source.playMethod,
      ),
    );
  }

  Future<void> _runPlaybackReport(
    String event,
    Future<void> Function() report,
  ) async {
    try {
      await report();
    } catch (error, stackTrace) {
      // Playback reporting is best-effort. A temporary server failure must not
      // interrupt a stream that is already initialized and playing correctly.
      debugPrint('Unable to report playback $event: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
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
    final airPlayConnected = nativeCastController.airPlayConnected;
    final airPlayJustConnected = airPlayConnected && !_wasAirPlayConnected;
    final routePickerVisible = nativeCastController.airPlayRoutePickerVisible;
    final routePickerJustClosed =
        _wasAirPlayRoutePickerVisible && !routePickerVisible;
    _wasAirPlayConnected = airPlayConnected;
    _wasAirPlayRoutePickerVisible = routePickerVisible;
    if (!airPlayConnected && !routePickerVisible && !routePickerJustClosed) {
      _airPlayStreamPrepared = false;
    }
    if ((airPlayJustConnected || routePickerJustClosed) &&
        !_airPlayStreamPrepared &&
        widget.media.localFilePath == null) {
      final positionTicks = _positionTicks;
      unawaited(_switchToAirPlayCompatibleStream(positionTicks));
    }
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

  Future<void> _switchToAirPlayCompatibleStream(int positionTicks) async {
    if (_switchingToAirPlayStream || _changingStream) return;
    _switchingToAirPlayStream = true;
    _airPlayStreamPrepared = true;
    try {
      final switched = await _openStream(
        startTicks: positionTicks,
        forceCompatiblePlayback: true,
        omitPlaybackHeaders: true,
      );
      if (!switched && mounted) {
        _airPlayStreamPrepared = false;
        setState(() {
          _error = context.tr(
            'AirPlay could not start a compatible video stream.',
          );
        });
      }
    } finally {
      _switchingToAirPlayStream = false;
    }
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
    unawaited(_saveResumePosition());
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
                              routeButton:
                                  Platform.isIOS ||
                                      (Platform.isAndroid &&
                                          _playbackUri != null)
                                  ? NativeRouteButton(
                                      streamUrl: _playbackUri?.toString() ?? '',
                                      title: widget.media.title,
                                      contentType:
                                          _source?.transcodingUrl != null
                                          ? 'application/x-mpegURL'
                                          : 'video/${_source?.container ?? 'mp4'}',
                                      position: controller.value.position,
                                    )
                                  : null,
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
