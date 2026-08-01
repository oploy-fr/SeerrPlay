import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seerrplay/core/localization/app_localizations.dart';

final nativeCastController = NativeCastController();

class NativeCastController extends ChangeNotifier {
  NativeCastController() {
    _channel.setMethodCallHandler(_handleNativeCall);
    _airPlayChannel.setMethodCallHandler(_handleAirPlayCall);
  }

  static const _channel = MethodChannel('seerrplay/cast');
  static const _airPlayChannel = MethodChannel('seerrplay/airplay');

  bool connected = false;
  bool playing = false;
  Duration position = Duration.zero;
  String? deviceName;
  bool airPlayConnected = false;
  bool airPlayRoutePickerVisible = false;
  String? airPlayDeviceName;

  Future<void> configure({
    required String streamUrl,
    required String title,
    required String contentType,
    required Duration position,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('configure', {
      'url': streamUrl,
      'title': title,
      'contentType': contentType,
      'positionMs': position.inMilliseconds,
    });
  }

  Future<void> play() => _invoke('play');
  Future<void> pause() => _invoke('pause');
  Future<void> stop() => _invoke('stop');
  Future<void> seek(Duration position) =>
      _invoke('seek', {'positionMs': position.inMilliseconds});
  Future<void> setVolume(double volume) =>
      _invoke('volume', {'volume': volume});

  Future<bool> showRouteChooser() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('showRouteChooser') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> refreshAirPlayStatus() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final status = await _airPlayChannel.invokeMapMethod<String, Object?>(
      'getStatus',
    );
    _applyAirPlayStatus(status);
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    if (!connected || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>(method, arguments);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    final arguments = call.arguments is Map
        ? Map<Object?, Object?>.from(call.arguments as Map)
        : const <Object?, Object?>{};
    switch (call.method) {
      case 'castConnected':
        connected = true;
        deviceName = arguments['deviceName'] as String?;
      case 'castDisconnected':
        connected = false;
        playing = false;
        deviceName = null;
      case 'castStatus':
        connected = true;
        playing = arguments['playing'] == true;
        final positionMs = arguments['positionMs'];
        if (positionMs is num) {
          position = Duration(milliseconds: positionMs.toInt());
        }
    }
    notifyListeners();
  }

  Future<void> _handleAirPlayCall(MethodCall call) async {
    final arguments = call.arguments is Map
        ? Map<String, Object?>.from(call.arguments as Map)
        : const <String, Object?>{};
    switch (call.method) {
      case 'airPlayStatus':
        _applyAirPlayStatus(arguments);
      case 'routePickerVisibilityChanged':
        airPlayRoutePickerVisible = arguments['visible'] == true;
        notifyListeners();
    }
  }

  void _applyAirPlayStatus(Map<String, Object?>? status) {
    airPlayConnected = status?['connected'] == true;
    final name = status?['deviceName'] as String?;
    airPlayDeviceName = name?.trim().isNotEmpty == true ? name!.trim() : null;
    notifyListeners();
  }
}

class NativeRouteButton extends StatefulWidget {
  const NativeRouteButton({
    required this.streamUrl,
    required this.title,
    required this.contentType,
    required this.position,
    super.key,
  });

  final String streamUrl;
  final String title;
  final String contentType;
  final Duration position;

  @override
  State<NativeRouteButton> createState() => _NativeRouteButtonState();
}

class _NativeRouteButtonState extends State<NativeRouteButton> {
  @override
  void initState() {
    super.initState();
    _configureCast();
  }

  @override
  void didUpdateWidget(covariant NativeRouteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl ||
        oldWidget.title != widget.title) {
      _configureCast();
    }
  }

  Future<void> _configureCast() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await nativeCastController.refreshAirPlayStatus();
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await nativeCastController.configure(
      streamUrl: widget.streamUrl,
      title: widget.title,
      contentType: widget.contentType,
      position: widget.position,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: UiKitView(viewType: 'seerrplay/airplay_button'),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AnimatedBuilder(
        animation: nativeCastController,
        builder: (context, _) => SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            tooltip: context.tr('Google Cast'),
            onPressed: () async {
              final opened = await nativeCastController.showRouteChooser();
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr('Unable to open the Google Cast selector.'),
                    ),
                  ),
                );
              }
            },
            icon: Icon(
              nativeCastController.connected
                  ? Icons.cast_connected_rounded
                  : Icons.cast_rounded,
              color: nativeCastController.connected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              size: 24,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
