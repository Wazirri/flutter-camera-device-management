import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // This is called when the app is first launched
    // Setup any required iOS-specific configurations here
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle app state transitions
  override func applicationWillResignActive(_ application: UIApplication) {
    // App is about to become inactive (e.g., during a phone call)
    super.applicationWillResignActive(application)
  }
  
  override func applicationDidEnterBackground(_ application: UIApplication) {
    // App is now in the background
    super.applicationDidEnterBackground(application)
  }
  
  override func applicationWillEnterForeground(_ application: UIApplication) {
    // App is about to enter the foreground
    super.applicationWillEnterForeground(application)
  }
  
  override func applicationDidBecomeActive(_ application: UIApplication) {
    // App is now active again
    super.applicationDidBecomeActive(application)
    
    // Perform any additional setup needed when app becomes active
    NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
  }
}