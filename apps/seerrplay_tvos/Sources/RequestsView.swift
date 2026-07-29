import SwiftUI

struct RequestsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var requests: [RequestItem] = []
    @State private var filter: RequestStatus?
    @State private var loading = true
    @State private var errorMessage: String?

    private var filtered: [RequestItem] {
        guard let filter else { return requests }
        return requests.filter { $0.status == filter }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                VStack(spacing: 24) {
                    Picker("Status", selection: $filter) {
                        Text("All").tag(RequestStatus?.none)
                        ForEach(RequestStatus.allCases.filter { $0 != .unknown }, id: \.self) {
                            Text($0.title).tag(RequestStatus?.some($0))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 340)

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
                    } else if filtered.isEmpty {
                        Spacer()
                        EmptyStateView(
                            title: "No requests",
                            message: "No request matches this status.",
                            systemImage: "tray"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 280), spacing: 30)],
                                spacing: 34
                            ) {
                                ForEach(filtered) { request in
                                    NavigationLink {
                                        MediaDetailView(item: request.media)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 14) {
                                            MediaPosterCard(item: request.media, width: 230)
                                            Text(request.status.title)
                                                .font(.caption.bold())
                                                .foregroundStyle(statusColor(request.status))
                                        }
                                    }
                                    .buttonStyle(.card)
                                    .contextMenu {
                                        if request.status == .pending {
                                            Button("Delete request", role: .destructive) {
                                                Task { await delete(request) }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 24)
                        }
                    }
                }
                .padding(.horizontal, 70)
                .padding(.bottom, 50)
            }
            .navigationTitle("Your requests")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            requests = try await app.requests()
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }

    private func delete(_ request: RequestItem) async {
        do {
            try await app.deleteRequest(request.id)
            requests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func statusColor(_ status: RequestStatus) -> Color {
        switch status {
        case .completed: SeerrPlayTheme.available
        case .approved: SeerrPlayTheme.cyan
        case .pending: .orange
        case .declined, .failed: .red
        case .unknown: .secondary
        }
    }
}
