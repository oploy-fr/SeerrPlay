import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var app: AppModel
    @State private var kind: MediaKind = .movie
    @State private var items: [MediaItem] = []
    @State private var query = ""
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                VStack(spacing: 24) {
                    Picker("Media type", selection: $kind) {
                        Text("Movies").tag(MediaKind.movie)
                        Text("Series").tag(MediaKind.tv)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 600)

                    if loading {
                        Spacer()
                        ProgressView().controlSize(.large)
                        Spacer()
                    } else if let errorMessage {
                        Spacer()
                        ErrorStateView(message: errorMessage) {
                            Task { await load() }
                        }
                        Spacer()
                    } else if items.isEmpty {
                        Spacer()
                        EmptyStateView(
                            title: "No media found",
                            message: "Try another search or category.",
                            systemImage: "rectangle.stack.badge.minus"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 210), spacing: 28)],
                                spacing: 34
                            ) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        MediaDetailView(item: item)
                                    } label: {
                                        MediaPosterCard(item: item, width: 190)
                                    }
                                    .buttonStyle(TVMediaButtonStyle())
                                    .focusEffectDisabled()
                                }
                            }
                            .padding(.vertical, 20)
                        }
                    }
                }
                .padding(.horizontal, 70)
                .padding(.bottom, 50)
            }
            .navigationTitle("Discover")
            .searchable(text: $query, prompt: "Search this category")
        }
        .task(id: kind) { await load() }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items = try await app.discover(kind)
            } else {
                items = try await app.search(query).filter { $0.kind == kind }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}
