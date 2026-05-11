import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct FileTransferActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var progress: Double
    var transferredBytes: Int64
    var totalBytes: Int64
    var speedBytesPerSecond: Double
    var status: String
    var updatedAt: Date
  }

  var id: String
  var direction: String
  var fileName: String
}
