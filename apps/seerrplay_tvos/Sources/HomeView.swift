import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var content: HomeContent?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                Group {
                    if let content {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 46) {
                                if let featured = content.trending.first {
                                    FeaturedMedia(item: featured)
                                }
                                MediaServerRail(
                                    title: "Continue watching",
                                    items: content.continueWatching
                                )
                                RequestRail(
                                    title: "Your available requests",
                                    items: content.availableRequests
                                )
                                MediaRail(title: "Trending now", items: content.trending)
                                MediaRail(title: "Popular movies", items: content.popularMovies)
                                MediaRail(title: "Popular series", items: content.popularShows)
                            }
                            .padding(.horizontal, 70)
                            .padding(.bottom, 80)
                        }
                    } else if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await load() }
                        }
                    } else {
                        ProgressView("Loading your home…")
                            .controlSize(.large)
                    }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        errorMessage = nil
        do {
            content = try await app.loadHome()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FeaturedMedia: View {
    let item: MediaItem

    var body: some View {
        NavigationLink {
            MediaDetailView(item: item)
        } label: {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.backdropURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    LinearGradient(
                        colors: [SeerrPlayTheme.violet.opacity(0.35), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .frame(height: 520)
                .clipped()
                .overlay {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.95)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("TRENDING")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SeerrPlayTheme.cyan)
                    Text(item.title)
                        .font(.system(size: 52, weight: .bold))
                    Text(item.overview)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .frame(maxWidth: 820, alignment: .leading)
                    Label("View details", systemImage: "info.circle")
                        .font(.headline)
                }
                .padding(46)
            }
            .clipShape(RoundedRectangle(cornerRadius: 34))
        }
        .buttonStyle(TVMediaButtonStyle())
        .focusEffectDisabled()
    }
}

struct MediaRail: View {
    let title: String
    let items: [MediaItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedStringKey(title)).font(.title2.bold())
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 24) {
                        ForEach(items) { item in
                            NavigationLink {
                                MediaDetailView(item: item)
                            } label: {
                                MediaPosterCard(item: item)
                            }
                            .buttonStyle(TVMediaButtonStyle())
                            .focusEffectDisabled()
                        }
                    }
                    .padding(.vertical, 18)
                }
            }
        }
    }
}

struct MediaServerRail: View {
    let title: String
    let items: [MediaServerItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedStringKey(title)).font(.title2.bold())
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 24) {
                        ForEach(items) { item in
                            NavigationLink {
                                MediaServerDetailView(item: item)
                            } label: {
                                MediaServerPosterCard(item: item)
                            }
                            .buttonStyle(TVMediaButtonStyle())
                            .focusEffectDisabled()
                        }
                    }
                    .padding(.vertical, 18)
                }
            }
        }
    }
}

private struct RequestRail: View {
    let title: String
    let items: [RequestItem]

    var body: some View {
        if !items.isEmpty {
            MediaRail(title: title, items: items.map(\.media))
        }
    }
}
