import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct DownloadActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String
    var status: String
    var progress: Double
    var downloadedBytes: Int64
    var totalBytes: Int64
    var estimatedRemainingSeconds: Int?
  }

  var downloadId: String
}
