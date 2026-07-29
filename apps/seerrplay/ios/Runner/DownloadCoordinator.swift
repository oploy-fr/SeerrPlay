import ActivityKit
import Flutter
import Foundation

final class DownloadCoordinator: NSObject {
  static let shared = DownloadCoordinator()

  private let statusKey = "seerrplay_native_download_statuses_v1"
  private var eventSink: FlutterEventSink?
  private var backgroundCompletionHandler: (() -> Void)?
  private var lastActivityPercentage: [String: Int] = [:]

  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(
      withIdentifier: "app.seerrplay.client.background_downloads"
    )
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    configuration.allowsCellularAccess = true
    return URLSession(
      configuration: configuration,
      delegate: self,
      delegateQueue: nil
    )
  }()

  func register(with messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "seerrplay/downloads",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    FlutterEventChannel(
      name: "seerrplay/downloads/events",
      binaryMessenger: messenger
    ).setStreamHandler(self)
    _ = session
  }

  func handleEvents(completionHandler: @escaping () -> Void) {
    backgroundCompletionHandler = completionHandler
    _ = session
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
      return
    }
    switch call.method {
    case "start":
      start(arguments, result: result)
    case "status":
      guard let id = arguments["id"] as? String else {
        result(nil)
        return
      }
      result(statuses()[id])
    case "cancel":
      guard let id = arguments["id"] as? String else {
        result(nil)
        return
      }
      cancel(id: id, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(_ arguments: [String: Any], result: @escaping FlutterResult) {
    guard
      let id = arguments["id"] as? String,
      let urlValue = arguments["url"] as? String,
      let url = URL(string: urlValue),
      let destinationPath = arguments["destinationPath"] as? String,
      let title = arguments["title"] as? String
    else {
      result(FlutterError(code: "invalid_download", message: nil, details: nil))
      return
    }

    var request = URLRequest(url: url)
    if let headers = arguments["headers"] as? [String: String] {
      for (name, value) in headers {
        request.setValue(value, forHTTPHeaderField: name)
      }
    }
    let task = session.downloadTask(with: request)
    task.taskDescription = encode([
      "id": id,
      "destinationPath": destinationPath,
      "title": title,
    ])
    saveStatus(
      id: id,
      status: "downloading",
      progress: 0,
      downloadedBytes: 0,
      totalBytes: 0,
      error: nil
    )
    startActivity(id: id, title: title)
    task.resume()
    result(nil)
  }

  private func cancel(id: String, result: @escaping FlutterResult) {
    session.getAllTasks { tasks in
      for task in tasks where self.metadata(for: task)?["id"] == id {
        task.cancel()
      }
      self.endActivity(id: id, title: "", status: "Cancelled", progress: 0)
      result(nil)
    }
  }

  private func metadata(for task: URLSessionTask) -> [String: String]? {
    guard
      let description = task.taskDescription,
      let data = description.data(using: .utf8),
      let value = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else {
      return nil
    }
    return value
  }

  private func encode(_ value: [String: String]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: value) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private func statuses() -> [String: [String: Any]] {
    UserDefaults.standard.dictionary(forKey: statusKey) as? [String: [String: Any]] ?? [:]
  }

  private func saveStatus(
    id: String,
    status: String,
    progress: Double,
    downloadedBytes: Int64,
    totalBytes: Int64,
    error: String?
  ) {
    var allStatuses = statuses()
    var value: [String: Any] = [
      "id": id,
      "status": status,
      "progress": progress,
      "downloadedBytes": downloadedBytes,
      "totalBytes": totalBytes,
    ]
    if let error {
      value["error"] = error
    }
    allStatuses[id] = value
    UserDefaults.standard.set(allStatuses, forKey: statusKey)
    DispatchQueue.main.async {
      self.eventSink?(value)
    }
  }

  private func startActivity(id: String, title: String) {
    guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled else {
      return
    }
    let attributes = DownloadActivityAttributes(downloadId: id)
    let state = DownloadActivityAttributes.ContentState(
      title: title,
      status: "Downloading",
      progress: 0,
      downloadedBytes: 0,
      totalBytes: 0
    )
    _ = try? Activity.request(
      attributes: attributes,
      contentState: state,
      pushType: nil
    )
  }

  private func updateActivity(
    id: String,
    title: String,
    progress: Double,
    downloadedBytes: Int64,
    totalBytes: Int64
  ) {
    guard #available(iOS 16.1, *) else { return }
    let percentage = Int((progress * 100).rounded())
    guard lastActivityPercentage[id] != percentage else { return }
    lastActivityPercentage[id] = percentage
    let state = DownloadActivityAttributes.ContentState(
      title: title,
      status: "Downloading",
      progress: progress,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes
    )
    for activity in Activity<DownloadActivityAttributes>.activities
    where activity.attributes.downloadId == id {
      Task {
        await activity.update(using: state)
      }
    }
  }

  private func endActivity(
    id: String,
    title: String,
    status: String,
    progress: Double
  ) {
    guard #available(iOS 16.1, *) else { return }
    lastActivityPercentage.removeValue(forKey: id)
    let state = DownloadActivityAttributes.ContentState(
      title: title,
      status: status,
      progress: progress,
      downloadedBytes: 0,
      totalBytes: 0
    )
    for activity in Activity<DownloadActivityAttributes>.activities
    where activity.attributes.downloadId == id {
      Task {
        await activity.end(
          using: state,
          dismissalPolicy: status == "Available offline"
            ? .after(Date().addingTimeInterval(60))
            : .immediate
        )
      }
    }
  }
}

extension DownloadCoordinator: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

extension DownloadCoordinator: URLSessionDownloadDelegate {
  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard let metadata = metadata(for: downloadTask), let id = metadata["id"] else {
      return
    }
    let total = max(totalBytesExpectedToWrite, 0)
    let progress = total > 0 ? Double(totalBytesWritten) / Double(total) : 0
    saveStatus(
      id: id,
      status: "downloading",
      progress: progress,
      downloadedBytes: totalBytesWritten,
      totalBytes: total,
      error: nil
    )
    updateActivity(
      id: id,
      title: metadata["title"] ?? "SeerrPlay",
      progress: progress,
      downloadedBytes: totalBytesWritten,
      totalBytes: total
    )
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard
      let metadata = metadata(for: downloadTask),
      let id = metadata["id"],
      let destinationPath = metadata["destinationPath"]
    else {
      return
    }
    let destination = URL(fileURLWithPath: destinationPath)
    do {
      try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.moveItem(at: location, to: destination)
      let size = Int64(
        (try? FileManager.default.attributesOfItem(
          atPath: destination.path
        )[.size] as? NSNumber)?.int64Value ?? 0
      )
      saveStatus(
        id: id,
        status: "completed",
        progress: 1,
        downloadedBytes: size,
        totalBytes: size,
        error: nil
      )
      endActivity(
        id: id,
        title: metadata["title"] ?? "SeerrPlay",
        status: "Available offline",
        progress: 1
      )
    } catch {
      saveStatus(
        id: id,
        status: "failed",
        progress: 0,
        downloadedBytes: 0,
        totalBytes: 0,
        error: error.localizedDescription
      )
      endActivity(
        id: id,
        title: metadata["title"] ?? "SeerrPlay",
        status: "Download failed",
        progress: 0
      )
    }
  }
}

extension DownloadCoordinator: URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard
      let error,
      let metadata = metadata(for: task),
      let id = metadata["id"],
      statuses()[id]?["status"] as? String != "completed"
    else {
      return
    }
    saveStatus(
      id: id,
      status: "failed",
      progress: 0,
      downloadedBytes: task.countOfBytesReceived,
      totalBytes: task.countOfBytesExpectedToReceive,
      error: error.localizedDescription
    )
    endActivity(
      id: id,
      title: metadata["title"] ?? "SeerrPlay",
      status: "Download failed",
      progress: 0
    )
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
      self.backgroundCompletionHandler?()
      self.backgroundCompletionHandler = nil
    }
  }
}
