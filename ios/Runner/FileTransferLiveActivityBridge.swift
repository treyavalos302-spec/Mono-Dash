import ActivityKit
import Flutter
import Foundation

final class FileTransferLiveActivityBridge {
  private static let channelName = "mono_dash/file_transfer_live_activity"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported":
        result(isSupported)
      case "start":
        if #available(iOS 16.1, *) {
          run(result) {
            try await start(from: call.arguments)
          }
        } else {
          result(nil)
        }
      case "update":
        if #available(iOS 16.1, *) {
          run(result) {
            try await update(from: call.arguments)
          }
        } else {
          result(nil)
        }
      case "end":
        if #available(iOS 16.1, *) {
          run(result) {
            try await end(from: call.arguments)
          }
        } else {
          result(nil)
        }
      case "endAll":
        if #available(iOS 16.1, *) {
          run(result) {
            try await endAll()
          }
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static var isSupported: Bool {
    if #available(iOS 16.1, *) {
      return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    return false
  }

  private static func run(
    _ result: @escaping FlutterResult,
    operation: @escaping () async throws -> Void
  ) {
    Task {
      do {
        try await operation()
        await MainActor.run {
          result(nil)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "LIVE_ACTIVITY_ERROR",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  @available(iOS 16.1, *)
  private static func start(from arguments: Any?) async throws {
    guard isSupported else { return }
    let args = try argumentsMap(arguments)
    let id = stringValue(args["id"])
    guard !id.isEmpty else { return }

    if let activity = activity(for: id) {
      await update(activity, state: state(from: args))
      return
    }

    let attributes = FileTransferActivityAttributes(
      id: id,
      direction: stringValue(args["direction"], fallback: "download"),
      fileName: stringValue(args["fileName"], fallback: "File")
    )

    if #available(iOS 16.2, *) {
      _ = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state(from: args), staleDate: nil),
        pushType: nil
      )
    } else {
      _ = try Activity.request(
        attributes: attributes,
        contentState: state(from: args),
        pushType: nil
      )
    }
  }

  @available(iOS 16.1, *)
  private static func update(from arguments: Any?) async throws {
    let args = try argumentsMap(arguments)
    let id = stringValue(args["id"])
    guard let activity = activity(for: id) else { return }
    await update(activity, state: state(from: args))
  }

  @available(iOS 16.1, *)
  private static func end(from arguments: Any?) async throws {
    let args = try argumentsMap(arguments)
    let id = stringValue(args["id"])
    guard let activity = activity(for: id) else { return }
    let state = state(from: args)

    if #available(iOS 16.2, *) {
      await activity.end(
        ActivityContent(state: state, staleDate: nil),
        dismissalPolicy: dismissalPolicy(for: state.status)
      )
    } else {
      await activity.end(
        using: state,
        dismissalPolicy: dismissalPolicy(for: state.status)
      )
    }
  }

  @available(iOS 16.1, *)
  private static func endAll() async throws {
    for activity in Activity<FileTransferActivityAttributes>.activities {
      let state = FileTransferActivityAttributes.ContentState(
        progress: 0,
        transferredBytes: 0,
        totalBytes: 0,
        speedBytesPerSecond: 0,
        status: "cancelled",
        updatedAt: Date()
      )
      if #available(iOS 16.2, *) {
        await activity.end(
          ActivityContent(state: state, staleDate: nil),
          dismissalPolicy: .immediate
        )
      } else {
        await activity.end(using: state, dismissalPolicy: .immediate)
      }
    }
  }

  @available(iOS 16.1, *)
  private static func update(
    _ activity: Activity<FileTransferActivityAttributes>,
    state: FileTransferActivityAttributes.ContentState
  ) async {
    if #available(iOS 16.2, *) {
      await activity.update(ActivityContent(state: state, staleDate: nil))
    } else {
      await activity.update(using: state)
    }
  }

  @available(iOS 16.1, *)
  private static func activity(
    for id: String
  ) -> Activity<FileTransferActivityAttributes>? {
    Activity<FileTransferActivityAttributes>.activities.first {
      $0.attributes.id == id
    }
  }

  @available(iOS 16.1, *)
  private static func state(
    from args: [String: Any]
  ) -> FileTransferActivityAttributes.ContentState {
    let progress = doubleValue(args["progress"]).clamped(to: 0...1)
    let totalBytes = int64Value(args["totalBytes"])
    let transferredBytes = int64Value(args["transferredBytes"])

    return FileTransferActivityAttributes.ContentState(
      progress: progress,
      transferredBytes: transferredBytes,
      totalBytes: totalBytes,
      speedBytesPerSecond: max(0, doubleValue(args["speedBytesPerSecond"])),
      status: stringValue(args["status"], fallback: "running"),
      updatedAt: Date()
    )
  }

  @available(iOS 16.1, *)
  private static func dismissalPolicy(
    for status: String
  ) -> ActivityUIDismissalPolicy {
    switch status {
    case "completed":
      return .after(Date().addingTimeInterval(8))
    case "failed", "cancelled":
      return .after(Date().addingTimeInterval(4))
    default:
      return .default
    }
  }

  private static func argumentsMap(_ arguments: Any?) throws -> [String: Any] {
    guard let arguments = arguments as? [String: Any] else {
      throw BridgeError.invalidArguments
    }
    return arguments
  }

  private static func stringValue(
    _ value: Any?,
    fallback: String = ""
  ) -> String {
    if let value = value as? String { return value }
    if let value { return String(describing: value) }
    return fallback
  }

  private static func doubleValue(_ value: Any?) -> Double {
    if let value = value as? Double { return value }
    if let value = value as? Float { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    if let value = value as? String { return Double(value) ?? 0 }
    return 0
  }

  private static func int64Value(_ value: Any?) -> Int64 {
    if let value = value as? Int64 { return value }
    if let value = value as? Int { return Int64(value) }
    if let value = value as? NSNumber { return value.int64Value }
    if let value = value as? String { return Int64(value) ?? 0 }
    return 0
  }
}

private enum BridgeError: LocalizedError {
  case invalidArguments

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "Invalid Live Activity arguments."
    }
  }
}

private extension Comparable {
  func clamped(to limits: ClosedRange<Self>) -> Self {
    min(max(self, limits.lowerBound), limits.upperBound)
  }
}
