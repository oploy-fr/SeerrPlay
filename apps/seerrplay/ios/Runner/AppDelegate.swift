import Flutter
import UIKit
import AVFoundation
import AVKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "app.seerrplay.client.request_status_poll",
      frequency: NSNumber(value: 15 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    if identifier == "app.seerrplay.client.background_downloads" {
      DownloadCoordinator.shared.handleEvents(completionHandler: completionHandler)
      return
    }
    completionHandler()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let downloadRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "SeerrPlayDownloadPlugin"
    )
    if let messenger = downloadRegistrar?.messenger() {
      DownloadCoordinator.shared.register(with: messenger)
    }
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SeerrPlayAirPlayPlugin")
    if let registrar {
      AirPlayCoordinator.shared.register(with: registrar.messenger())
      registrar.register(
        AirPlayButtonFactory(coordinator: AirPlayCoordinator.shared),
        withId: "seerrplay/airplay_button"
      )
    }
  }
}

private final class AirPlayButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let coordinator: AirPlayCoordinator

  init(coordinator: AirPlayCoordinator) {
    self.coordinator = coordinator
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    AirPlayButtonView(frame: frame, coordinator: coordinator)
  }
}

private final class AirPlayButtonView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect, coordinator: AirPlayCoordinator) {
    container = UIView(frame: frame)
    super.init()

    let routePicker = AVRoutePickerView(frame: container.bounds)
    routePicker.delegate = coordinator
    routePicker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    routePicker.prioritizesVideoDevices = true
    routePicker.tintColor = .white
    routePicker.activeTintColor = UIColor(red: 0.94, green: 0.22, blue: 0.27, alpha: 1)
    container.addSubview(routePicker)
  }

  func view() -> UIView {
    container
  }
}

private final class AirPlayCoordinator: NSObject, AVRoutePickerViewDelegate {
  static let shared = AirPlayCoordinator()

  private var channel: FlutterMethodChannel?
  private var routeObserver: NSObjectProtocol?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "seerrplay/airplay", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getStatus" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.statusPayload() ?? ["connected": false])
    }
    if routeObserver == nil {
      routeObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.sendStatus()
      }
    }
    sendStatus()
  }

  func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
    channel?.invokeMethod(
      "routePickerVisibilityChanged",
      arguments: ["visible": true]
    )
  }

  func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
    channel?.invokeMethod(
      "routePickerVisibilityChanged",
      arguments: ["visible": false]
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      self?.sendStatus()
    }
  }

  private func sendStatus() {
    channel?.invokeMethod("airPlayStatus", arguments: statusPayload())
  }

  private func statusPayload() -> [String: Any] {
    let output = AVAudioSession.sharedInstance().currentRoute.outputs.first {
      $0.portType == .airPlay
    }
    return [
      "connected": output != nil,
      "deviceName": output?.portName ?? ""
    ]
  }
}
