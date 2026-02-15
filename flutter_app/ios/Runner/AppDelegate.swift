import Flutter
import UIKit
import TencentOpenAPI

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Tencent OpenSDK 3.5.7+ requires explicit agreement before requesting user info.
    TencentOAuth.setIsUserAgreedAuthorization(true)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
