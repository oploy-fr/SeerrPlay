import ActivityKit
import SwiftUI
import WidgetKit

private let magenta = Color(red: 1, green: 0.25, blue: 0.60)
private let violet = Color(red: 0.56, green: 0.25, blue: 1)
private let cyan = Color(red: 0, green: 0.95, blue: 1)

@main
struct SeerrPlayDownloadActivityBundle: WidgetBundle {
  var body: some Widget {
    DownloadActivityWidget()
  }
}

struct DownloadActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 10) {
          Image(systemName: context.state.progress >= 1
            ? "checkmark.circle.fill"
            : "arrow.down.circle.fill")
            .font(.title2)
            .foregroundStyle(context.state.progress >= 1 ? cyan : magenta)
          VStack(alignment: .leading, spacing: 2) {
            Text(context.state.title)
              .font(.headline)
              .lineLimit(1)
            Text(context.state.status)
              .font(.caption)
              .foregroundStyle(.secondary)
            if let seconds = context.state.estimatedRemainingSeconds {
              Text(remainingTime(seconds))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          Spacer()
          Text("\(Int((context.state.progress * 100).rounded()))%")
            .font(.headline.monospacedDigit())
        }
        ProgressView(value: context.state.progress)
          .tint(violet)
      }
      .padding(16)
      .activityBackgroundTint(Color.black.opacity(0.92))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "arrow.down.circle.fill")
            .foregroundStyle(magenta)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.title)
            .font(.headline)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("\(Int((context.state.progress * 100).rounded()))%")
            .font(.headline.monospacedDigit())
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 4) {
            ProgressView(value: context.state.progress)
              .tint(violet)
            if let seconds = context.state.estimatedRemainingSeconds {
              Text(remainingTime(seconds))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          .padding(.horizontal, 4)
        }
      } compactLeading: {
        Image(systemName: "arrow.down")
          .foregroundStyle(magenta)
      } compactTrailing: {
        Text("\(Int((context.state.progress * 100).rounded()))%")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(cyan)
      } minimal: {
        Image(systemName: "arrow.down")
          .foregroundStyle(violet)
      }
      .widgetURL(URL(string: "seerrplay://downloads"))
      .keylineTint(violet)
    }
  }
}

private func remainingTime(_ seconds: Int) -> String {
  if seconds < 60 { return "< 1 min remaining" }
  let minutes = Int(ceil(Double(seconds) / 60))
  if minutes < 60 { return "\(minutes) min remaining" }
  let hours = minutes / 60
  let remainingMinutes = minutes % 60
  return remainingMinutes == 0
    ? "\(hours) h remaining"
    : "\(hours) h \(remainingMinutes) min remaining"
}
