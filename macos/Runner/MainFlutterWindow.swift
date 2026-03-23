import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame

    // Full-screen (green title bar button) + free resizing
    styleMask.insert(.resizable)
    collectionBehavior.insert(.fullScreenPrimary)
    if #available(macOS 10.11, *) {
      collectionBehavior.insert(.fullScreenAllowsTiling)
    }
    minSize = NSSize(width: 320, height: 360)
    maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    resizeIncrements = NSSize(width: 1, height: 1)

    contentViewController = flutterViewController
    setFrame(windowFrame, display: true)

    flutterViewController.view.autoresizingMask = [.width, .height]

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
