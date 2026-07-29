import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        profileSection
                        connectionSection
                        privacySection
                        aboutSection
                    }
                    .padding(70)
                }
            }
            .navigationTitle("Settings")
        }
        .confirmationDialog(
            "Delete this local profile?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete profile", role: .destructive) {
                if let profile = app.activeProfile {
                    app.deleteProfile(profile)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Credentials and local profile data will be removed from this Apple TV.")
        }
    }

    private var profileSection: some View {
        SettingsCard(title: "Current profile", systemImage: "person.crop.square") {
            HStack(spacing: 25) {
                if let profile = app.activeProfile {
                    ProfileAvatar(index: profile.avatarIndex, size: 105)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name).font(.title2.bold())
                        Text("Seerr: \(app.seerrDisplayName)")
                        Text(
                            "\(profile.mediaServerType.title): \(app.mediaServerDisplayName)"
                        )
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Switch profile") {
                    app.showProfileSelection()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var connectionSection: some View {
        SettingsCard(title: "Direct connections", systemImage: "network") {
            if let profile = app.activeProfile {
                SettingsValue(label: "Seerr", value: profile.seerrURL.absoluteString)
                SettingsValue(
                    label: profile.mediaServerType.title,
                    value: profile.mediaServerURL.absoluteString
                )
            }
            Text("SeerrPlay communicates directly with your configured servers. No SeerrPlay cloud or intermediary gateway is used.")
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        SettingsCard(title: "Privacy and data", systemImage: "hand.raised") {
            NavigationLink("Privacy policy") {
                InformationView(type: .privacy)
            }
            NavigationLink("Terms of use") {
                InformationView(type: .terms)
            }
            Button("Delete local profile data", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }

    private var aboutSection: some View {
        SettingsCard(title: "About", systemImage: "info.circle") {
            BrandMark(compact: true)
            Text("Independent, unofficial client for Seerr and personal media servers.")
                .foregroundStyle(.secondary)
            NavigationLink("Credits") {
                CreditsView()
            }
            Text("Version 1.0.0 (1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CreditsView: View {
    private let projects: [(String, String, URL)] = [
        (
            "Seerr",
            "Media discovery and request management",
            URL(string: "https://github.com/seerr-team/seerr")!
        ),
        (
            "Jellyfin",
            "Open-source media server",
            URL(string: "https://jellyfin.org")!
        ),
        (
            "Plex",
            "Personal media server",
            URL(string: "https://www.plex.tv")!
        ),
        (
            "Emby",
            "Personal media server",
            URL(string: "https://emby.media")!
        ),
        (
            "Flutter",
            "Cross-platform application framework",
            URL(string: "https://flutter.dev")!
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                BrandMark(compact: true)
                Text("Credits")
                    .font(.system(size: 48, weight: .bold))

                Link(destination: URL(string: "https://www.themoviedb.org")!) {
                    VStack(alignment: .leading, spacing: 20) {
                        Image("TMDBLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 360)
                        Text(
                            verbatim: "This product uses the TMDB API but is not endorsed or certified by TMDB."
                        )
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(
                        .white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 28)
                    )
                }
                .buttonStyle(.plain)

                ForEach(projects, id: \.0) { project in
                    Link(destination: project.2) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(project.0).font(.title2.bold())
                                Text(LocalizedStringKey(project.1))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                }

                Link(
                    "View SeerrPlay on GitHub",
                    destination: URL(string: "https://github.com/oploy-fr/SeerrPlay")!
                )
                .buttonStyle(.bordered)
            }
            .padding(70)
        }
        .background(PageBackground())
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label(title, systemImage: systemImage)
                .font(.title2.bold())
            Divider()
            content
        }
        .padding(34)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28))
    }
}

private struct SettingsValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.headline)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private enum InformationType {
    case privacy
    case terms
}

private struct InformationView: View {
    let type: InformationType

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                BrandMark(compact: true)
                Text(type == .privacy ? "Privacy policy" : "Terms of use")
                    .font(.system(size: 48, weight: .bold))
                ForEach(sections, id: \.0) { title, body in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title).font(.title2.bold())
                        Text(body)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .lineSpacing(7)
                    }
                }
            }
            .padding(70)
        }
        .background(PageBackground())
    }

    private var sections: [(String, String)] {
        switch type {
        case .privacy:
            [
                (
                    "Direct server communication",
                    "Searches, requests, playback state and media information are exchanged directly with the Seerr and personal media servers selected by the user."
                ),
                (
                    "On-device storage",
                    "Profiles are stored on this Apple TV. Authentication credentials and sessions are stored in the system Keychain."
                ),
                (
                    "No advertising or analytics",
                    "SeerrPlay does not currently include advertising, developer analytics or cross-application tracking."
                ),
                (
                    "Data deletion",
                    "Deleting a profile removes its local connection information, credentials and session data from this Apple TV."
                ),
            ]
        case .terms:
            [
                (
                    "Authorized access only",
                    "You must only connect to servers, libraries and media that you own or are authorized to use."
                ),
                (
                    "No media service",
                    "SeerrPlay does not sell, provide or host films, series, subscriptions or download sources."
                ),
                (
                    "Third-party services",
                    "Availability and operation depend on the Seerr and personal media servers configured by the user and their administrators."
                ),
                (
                    "Independent application",
                    "SeerrPlay is an independent, unofficial client and is not affiliated with Seerr, Plex, Jellyfin, or Emby."
                ),
            ]
        }
    }
}
