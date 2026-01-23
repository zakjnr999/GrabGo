import Flutter
import UIKit
import GoogleMaps
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBvSX6emxtbMNjweHsnetgASW7vCmBysGQ")
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Native Location Plugin
    NativeLocationPlugin.register(with: self.registrar(forPlugin: "NativeLocationPlugin")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
