import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        switch app.phase {
        case .launching, .connecting:
            ZStack {
                PageBackground()
                VStack(spacing: 28) {
                    BrandMark()
                    ProgressView()
                        .controlSize(.large)
                    Text(app.phase == .connecting ? "Connecting to your servers…" : "Loading…")
                        .foregroundStyle(.secondary)
                }
            }
        case .profileSelection:
            ProfileSelectionView()
        case .ready:
            MainTabView()
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "rectangle.grid.2x2") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            RequestsView()
                .tabItem { Label("Requests", systemImage: "tray.full") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "play.rectangle.on.rectangle") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(SeerrPlayTheme.violet)
        .environmentObject(app)
    }
}
