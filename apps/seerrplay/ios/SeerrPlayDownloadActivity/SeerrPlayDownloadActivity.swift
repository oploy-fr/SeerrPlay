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
          ProgressView(value: context.state.progress)
            .tint(violet)
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
