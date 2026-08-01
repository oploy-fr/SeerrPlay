import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""
    @State private var results: [MediaItem] = []
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                Group {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EmptyStateView(
                            title: "Search Seerr",
                            message: "Find movies and series using localized or original titles.",
                            systemImage: "magnifyingglass"
                        )
                    } else if loading {
                        ProgressView("Searching…").controlSize(.large)
                    } else if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await search() }
                        }
                    } else if results.isEmpty {
                        EmptyStateView(
                            title: "No results",
                            message: "No title matches “\(query)”.",
                            systemImage: "questionmark.folder"
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 210), spacing: 28)],
                                spacing: 34
                            ) {
                                ForEach(results) { item in
                                    NavigationLink {
                                        MediaDetailView(item: item)
                                    } label: {
                                        MediaPosterCard(item: item, width: 190)
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
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Movie or series")
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private func search() async {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            results = []
            return
        }
        loading = true
        errorMessage = nil
        do {
            results = try await app.search(clean)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
        loading = false
    }
}
