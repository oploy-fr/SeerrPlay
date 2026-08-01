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
    @State private var selection: MainSection = .home
    @State private var showingProfiles = false

    var body: some View {
        VStack(spacing: 0) {
            TVTopNavigation(
                selection: $selection,
                profileName: app.activeProfile?.name ?? String(localized: "Profile"),
                profileAvatarIndex: app.activeProfile?.avatarIndex ?? 0,
                onProfileSelected: { showingProfiles = true }
            )

            ZStack(alignment: .topLeading) {
                if showingProfiles {
                    ProfileSelectionView()
                    Button {
                        showingProfiles = false
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .padding(.leading, 54)
                    .padding(.top, 28)
                } else {
                    selectedContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PageBackground())
        .environmentObject(app)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selection {
        case .home: HomeView()
        case .discover: DiscoverView()
        case .search: SearchView()
        case .requests: RequestsView()
        case .library: LibraryView()
        case .settings: SettingsView()
        }
    }
}

private enum MainSection: String, CaseIterable, Identifiable {
    case home
    case discover
    case search
    case requests
    case library
    case settings

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .discover: "Discover"
        case .search: "Search"
        case .requests: "Requests"
        case .library: "Library"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .discover: "rectangle.grid.2x2"
        case .search: "magnifyingglass"
        case .requests: "tray.full"
        case .library: "play.rectangle.on.rectangle"
        case .settings: "gearshape"
        }
    }
}

private struct TVTopNavigation: View {
    @Binding var selection: MainSection
    let profileName: String
    let profileAvatarIndex: Int
    let onProfileSelected: () -> Void

    @FocusState private var focusedItem: String?

    var body: some View {
        ZStack {
            HStack {
                BrandMark(compact: true)
                Spacer()
                profileButton
            }

            HStack(spacing: 34) {
                ForEach(MainSection.allCases) { section in
                    Button {
                        selection = section
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 19, weight: .medium))
                            Text(section.title)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .foregroundStyle(
                            selection == section || focusedItem == section.rawValue
                                ? .white
                                : .white.opacity(0.52)
                        )
                        .padding(.vertical, 17)
                        .scaleEffect(focusedItem == section.rawValue ? 1.06 : 1)
                        .animation(.easeOut(duration: 0.16), value: focusedItem)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .focused($focusedItem, equals: section.rawValue)
                }
            }
        }
        .frame(height: 92)
        .padding(.horizontal, 54)
        .background(.black.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
        .zIndex(20)
    }

    private var profileButton: some View {
        Button(action: onProfileSelected) {
            HStack(spacing: 12) {
                ProfileAvatar(index: profileAvatarIndex, size: 45)
                Text(profileName)
                    .font(.system(size: 19, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: 150)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(focusedItem == "profile" ? .white : .white.opacity(0.82))
            .scaleEffect(focusedItem == "profile" ? 1.05 : 1)
            .animation(.easeOut(duration: 0.16), value: focusedItem)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .focused($focusedItem, equals: "profile")
    }
}
