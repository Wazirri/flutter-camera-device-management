import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Fix keyboard focus issue on macOS - activate the app and bring window to front
    NSApplication.shared.activate(ignoringOtherApps: true)
    if let window = NSApplication.shared.windows.first {
      window.makeKeyAndOrderFront(nil)
      window.makeFirstResponder(window.contentView)
    }
  }
  
  override func applicationDidBecomeActive(_ notification: Notification) {
    // Ensure keyboard focus when app becomes active
    if let window = NSApplication.shared.keyWindow {
      window.makeFirstResponder(window.contentView)
    }
  }
}