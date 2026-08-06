import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let settingsChannel = FlutterMethodChannel(
      name: "com.minutmate.ssdmanager/settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    settingsChannel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let settingsURL = if #available(iOS 16.0, *) {
        UIApplication.openNotificationSettingsURLString
      } else {
        UIApplication.openSettingsURLString
      }
      guard let url = URL(string: settingsURL) else {
        result(FlutterError(code: "settings_unavailable", message: "App-Einstellungen konnten nicht geöffnet werden.", details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        if opened {
          result(nil)
        } else {
          result(FlutterError(code: "settings_unavailable", message: "App-Einstellungen konnten nicht geöffnet werden.", details: nil))
        }
      }
    }
  }
}
