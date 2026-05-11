import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    LocalNetworkAuthorization().requestAuthorization { _ in }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let widgetRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ServerWidgetBridge") {
      ServerWidgetBridge.register(with: widgetRegistrar)
    }

    if let transferRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FileTransferLiveActivityBridge") {
      FileTransferLiveActivityBridge.register(with: transferRegistrar)
    }
  }
}
