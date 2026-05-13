import Flutter
import Foundation

final class ICloudKeyValueBridge {
  private static let channelName = "mono_dash/icloud_kvs"
  private static var channel: FlutterMethodChannel?
  private static var observer: NSObjectProtocol?

  static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel = methodChannel

    methodChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        start()
        result(nil)
      case "isAvailable":
        result(FileManager.default.ubiquityIdentityToken != nil)
      case "getString":
        guard let key = key(from: call.arguments) else {
          result(FlutterError(code: "bad_args", message: "Missing key", details: nil))
          return
        }
        result(NSUbiquitousKeyValueStore.default.string(forKey: key))
      case "setString":
        guard
          let arguments = call.arguments as? [String: Any],
          let key = arguments["key"] as? String,
          let value = arguments["value"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "Missing key or value", details: nil))
          return
        }
        NSUbiquitousKeyValueStore.default.set(value, forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    start()
  }

  private static func start() {
    if observer == nil {
      observer = NotificationCenter.default.addObserver(
        forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
        object: NSUbiquitousKeyValueStore.default,
        queue: .main
      ) { notification in
        notifyChangedKeys(from: notification)
      }
    }
    NSUbiquitousKeyValueStore.default.synchronize()
  }

  private static func notifyChangedKeys(from notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
    else { return }

    for key in keys {
      channel?.invokeMethod("remoteValueChanged", arguments: ["key": key])
    }
  }

  private static func key(from arguments: Any?) -> String? {
    guard
      let arguments = arguments as? [String: Any],
      let key = arguments["key"] as? String,
      !key.isEmpty
    else { return nil }
    return key
  }
}
