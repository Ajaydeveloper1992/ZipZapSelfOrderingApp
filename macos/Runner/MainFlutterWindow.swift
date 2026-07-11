import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    
    // Set initial window size
    let initialWidth: CGFloat = 1400
    let initialHeight: CGFloat = 900
    
    // Center the window on screen
    if let screen = NSScreen.main {
      let screenRect = screen.visibleFrame
      let x = (screenRect.width - initialWidth) / 2 + screenRect.origin.x
      let y = (screenRect.height - initialHeight) / 2 + screenRect.origin.y
      
      let windowFrame = NSRect(
        x: x,
        y: y,
        width: initialWidth,
        height: initialHeight
      )
      
      self.setFrame(windowFrame, display: true)
    } else {
      // Fallback if screen info is not available
      let windowFrame = NSRect(
        x: 0,
        y: 0,
        width: initialWidth,
        height: initialHeight
      )
      self.setFrame(windowFrame, display: true)
    }
    
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
