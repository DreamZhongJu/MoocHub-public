import Flutter
import UIKit
import TencentOpenAPI

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 手Q OpenSDK 3.5.7+ 权限兜底：用户未授权设备信息前，需显式放行
    TencentOAuth.setIsUserAgreedAuthorization(true)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
