import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowControlChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 1050, height: 720)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    windowControlChannel = FlutterMethodChannel(
      name: "app.seerrplay/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowControlChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }
      switch call.method {
      case "isFullscreen":
        result(self.styleMask.contains(.fullScreen))
      case "toggleFullscreen":
        let targetState = !self.styleMask.contains(.fullScreen)
        self.toggleFullScreen(nil)
        result(targetState)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
