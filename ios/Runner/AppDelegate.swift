import Flutter
import UIKit
import GoogleMaps
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let mapsConfigurationChannel = "omnicare/maps_configuration"
  private var mapsConfigurationMethodChannel: FlutterMethodChannel?
  private var isMapsApiKeyConfigured = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    if let apiKey = configuredMapsApiKey() {
      isMapsApiKeyConfigured = GMSServices.provideAPIKey(apiKey)
    } else {
      NSLog("OmniCare Maps is disabled: MAPS_API_KEY is not configured.")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: Self.mapsConfigurationChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "status" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result([
        "configured": self?.isMapsApiKeyConfigured == true,
        "platform": "ios",
      ])
    }
    mapsConfigurationMethodChannel = channel
  }

  private func configuredMapsApiKey() -> String? {
    guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String else {
      return nil
    }
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.hasPrefix("AIza"),
          value.count >= 30,
          !value.contains("$("),
          !value.contains("%") else {
      return nil
    }
    return value
  }
}
