import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard
      let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController
    else {
      super.applicationDidFinishLaunching(notification)
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.podcasts.safetynet/nowplaying",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "getNowPlaying" {
        DispatchQueue.global(qos: .userInitiated).async {
          let info = AppleScriptBridge.getCurrentlyPlaying()
          DispatchQueue.main.async {
            result(info)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
