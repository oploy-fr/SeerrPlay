import SwiftUI

struct MediaPosterCard: View {
    let item: MediaItem
    var width: CGFloat = 210

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                PosterImage(url: item.posterURL, ratio: 2 / 3)
                    .frame(width: width, height: width * 1.5)
                if let availability = item.mediaInfo?.availability,
                   availability == .available || availability == .partiallyAvailable
                {
                    AvailabilityBadge(availability: availability)
                        .padding(10)
                }
            }
            Text(item.title)
                .font(.headline)
                .lineLimit(1)
            if let year = item.releaseDate.map({ Calendar.current.component(.year, from: $0) }) {
                Text(String(year))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

struct MediaServerPosterCard: View {
    @EnvironmentObject private var app: AppModel
    let item: MediaServerItem
    var width: CGFloat = 210
    @State private var imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                PosterImage(url: imageURL, ratio: 2 / 3)
                    .frame(width: width, height: width * 1.5)
                if item.userData.playbackPositionTicks > 0,
                   let runtime = item.runtimeTicks,
                   runtime > 0
                {
                    ProgressView(
                        value: Double(item.userData.playbackPositionTicks),
                        total: Double(runtime)
                    )
                    .tint(.white)
                    .padding(10)
                }
            }
            Text(item.displayTitle)
                .font(.headline)
                .lineLimit(1)
            if item.type == "Episode" {
                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .task(id: item.id) {
            imageURL = await app.mediaServerImage(item)
        }
    }
}

struct PosterImage: View {
    let url: URL?
    let ratio: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder
            case .empty:
                ZStack {
                    placeholder
                    ProgressView()
                }
            @unknown default:
                placeholder
            }
        }
        .aspectRatio(ratio, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [SeerrPlayTheme.violet.opacity(0.5), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 58))
                .foregroundStyle(SeerrPlayTheme.violet)
            Text(LocalizedStringKey(title)).font(.title2.bold())
            Text(LocalizedStringKey(message))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 720)
        .padding(50)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Unable to load this page")
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(50)
    }
}
