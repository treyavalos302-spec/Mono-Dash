import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private enum LaunchFlags {
    static let hasCompletedInitialRun = "cc.boring-lab.monodash.hasCompletedInitialRun"
    static let localNetworkAuthorizationRequested =
      "cc.boring-lab.monodash.localNetworkAuthorizationRequested"
  }

  private var localNetworkAuthorization: LocalNetworkAuthorization?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    requestLocalNetworkAuthorizationIfNeeded()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let widgetRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ServerWidgetBridge") {
      ServerWidgetBridge.register(with: widgetRegistrar)
    }

    if let iCloudRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudKeyValueBridge") {
      ICloudKeyValueBridge.register(with: iCloudRegistrar)
    }

    if let transferRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "FileTransferLiveActivityBridge") {
      FileTransferLiveActivityBridge.register(with: transferRegistrar)
    }
  }

  private func requestLocalNetworkAuthorizationIfNeeded() {
    guard shouldRequestLocalNetworkAuthorizationOnLaunch() else { return }

    let authorization = LocalNetworkAuthorization()
    localNetworkAuthorization = authorization
    authorization.requestAuthorization { [weak self] _ in
      self?.localNetworkAuthorization = nil
    }
  }

  private func shouldRequestLocalNetworkAuthorizationOnLaunch() -> Bool {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: LaunchFlags.localNetworkAuthorizationRequested) {
      defaults.set(true, forKey: LaunchFlags.hasCompletedInitialRun)
      return false
    }

    if defaults.bool(forKey: LaunchFlags.hasCompletedInitialRun) {
      defaults.set(true, forKey: LaunchFlags.localNetworkAuthorizationRequested)
      return false
    }

    if hasExistingAppDefaults() || hasExistingAppData() {
      defaults.set(true, forKey: LaunchFlags.hasCompletedInitialRun)
      defaults.set(true, forKey: LaunchFlags.localNetworkAuthorizationRequested)
      return false
    }

    defaults.set(true, forKey: LaunchFlags.hasCompletedInitialRun)
    defaults.set(true, forKey: LaunchFlags.localNetworkAuthorizationRequested)
    return true
  }

  private func hasExistingAppDefaults() -> Bool {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier,
      let domain = UserDefaults.standard.persistentDomain(forName: bundleIdentifier)
    else {
      return false
    }

    let launchFlagKeys: Set<String> = [
      LaunchFlags.hasCompletedInitialRun,
      LaunchFlags.localNetworkAuthorizationRequested,
    ]
    return domain.keys.contains { key in
      !launchFlagKeys.contains(key)
    }
  }

  private func hasExistingAppData() -> Bool {
    guard let documentsURL = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      return false
    }

    let contents = (try? FileManager.default.contentsOfDirectory(
      atPath: documentsURL.path
    )) ?? []
    return contents.contains { name in
      !name.hasPrefix(".")
    }
  }
}
