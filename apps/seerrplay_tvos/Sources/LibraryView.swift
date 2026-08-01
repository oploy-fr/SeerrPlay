import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var app: AppModel
    @State private var items: [MediaServerItem] = []
    @State private var query = ""
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                Group {
                    if loading {
                        ProgressView("Loading media library…").controlSize(.large)
                    } else if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await load() }
                        }
                    } else if items.isEmpty {
                        EmptyStateView(
                            title: "No media",
                            message: "Nothing matches this media library search.",
                            systemImage: "play.rectangle"
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 210), spacing: 28)],
                                spacing: 34
                            ) {
                                ForEach(items) { item in
                                    NavigationLink {
                                        MediaServerDetailView(item: item)
                                    } label: {
                                        MediaServerPosterCard(item: item, width: 190)
                                    }
                                    .buttonStyle(TVMediaButtonStyle())
                                    .focusEffectDisabled()
                                }
                            }
                            .padding(70)
                        }
                    }
                }
            }
            .navigationTitle("Media library")
            .searchable(text: $query, prompt: "Search your library")
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            items = try await app.library(search: query)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        loading = false
    }
}
