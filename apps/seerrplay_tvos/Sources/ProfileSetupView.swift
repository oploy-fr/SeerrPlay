import SwiftUI

struct ProfileSelectionView: View {
    @EnvironmentObject private var app: AppModel
    @State private var showingSetup = false

    var body: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 42) {
                BrandMark()
                Text("Who is watching?")
                    .font(.largeTitle.bold())

                ScrollView(.horizontal) {
                    HStack(spacing: 34) {
                        ForEach(app.profiles) { profile in
                            Button {
                                Task { await app.activate(profile) }
                            } label: {
                                VStack(spacing: 16) {
                                    ProfileAvatar(index: profile.avatarIndex, size: 150)
                                    Text(profile.name)
                                        .font(.title3.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .frame(width: 210, height: 250)
                            }
                            .buttonStyle(TVMediaButtonStyle())
                            .focusEffectDisabled()
                            .contextMenu {
                                Button("Delete profile", role: .destructive) {
                                    app.deleteProfile(profile)
                                }
                            }
                        }

                        Button {
                            showingSetup = true
                        } label: {
                            VStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(.white.opacity(0.08))
                                    Image(systemName: "plus")
                                        .font(.system(size: 54, weight: .medium))
                                }
                                .frame(width: 150, height: 150)
                                Text("Add profile")
                                    .font(.headline.weight(.semibold))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.75)
                                    .frame(height: 64)
                            }
                            .frame(width: 280, height: 250)
                        }
                        .buttonStyle(TVMediaButtonStyle())
                        .focusEffectDisabled()
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 24)
                    .frame(minWidth: 1500, alignment: .center)
                }
                .frame(maxWidth: 1600)

                if let error = app.globalError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .frame(maxWidth: 900)
                }
            }
            .padding(70)
        }
        .sheet(isPresented: $showingSetup) {
            ProfileSetupView()
                .environmentObject(app)
        }
    }
}

struct ProfileSetupView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var profileName = ""
    @State private var avatarIndex = 0
    @State private var seerrScheme = "https"
    @State private var seerrHost = ""
    @State private var seerrPort = ""
    @State private var mediaServerScheme = "https"
    @State private var mediaServerHost = ""
    @State private var mediaServerPort = ""
    @State private var loginMode: SeerrLoginMode = .local
    @State private var seerrUsername = ""
    @State private var seerrPassword = ""
    @State private var sameCredentials = true
    @State private var mediaServerUsername = ""
    @State private var mediaServerPassword = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Profile name", text: $profileName)
                    ScrollView(.horizontal) {
                        HStack(spacing: 22) {
                            ForEach(0 ..< 8, id: \.self) { index in
                                Button {
                                    avatarIndex = index
                                } label: {
                                    ProfileAvatar(index: index, size: 95)
                                        .overlay {
                                            if avatarIndex == index {
                                                RoundedRectangle(cornerRadius: 24)
                                                    .stroke(.white, lineWidth: 5)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Seerr server") {
                    ServerAddressFields(
                        scheme: $seerrScheme,
                        host: $seerrHost,
                        port: $seerrPort,
                        example: "seerr.example.com"
                    )
                    Picker("Sign in with", selection: $loginMode) {
                        ForEach(SeerrLoginMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    TextField(
                        loginMode == .local ? "Email" : "Username",
                        text: $seerrUsername
                    )
                    SecureField("Password", text: $seerrPassword)
                }

                Section("Media server (automatic detection)") {
                    ServerAddressFields(
                        scheme: $mediaServerScheme,
                        host: $mediaServerHost,
                        port: $mediaServerPort,
                        example: "Optional fallback address"
                    )
                    Toggle("Use the same credentials", isOn: $sameCredentials)
                    if !sameCredentials {
                        TextField("Media server username", text: $mediaServerUsername)
                        SecureField("Media server password", text: $mediaServerPassword)
                    }
                }

                if let code = app.plexLinkCode {
                    Section("Link Plex") {
                        Text(code)
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text("Open plex.tv/link on a phone or computer and enter this code.")
                    }
                }

                if seerrScheme == "http" || mediaServerScheme == "http" {
                    Section {
                        Label(
                            "HTTP does not encrypt credentials. Use it only on a trusted local network.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create a profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        connect()
                    } label: {
                        if isConnecting {
                            ProgressView()
                        } else {
                            Text("Connect")
                        }
                    }
                    .disabled(isConnecting || !isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !seerrHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (
                loginMode == .mediaServer
                    || (!seerrUsername.isEmpty && !seerrPassword.isEmpty)
            )
            && (sameCredentials || (!mediaServerUsername.isEmpty && !mediaServerPassword.isEmpty))
    }

    private func connect() {
        errorMessage = nil
        guard let seerrURL = serverURL(
            scheme: seerrScheme,
            host: seerrHost,
            port: seerrPort
        ) else {
            errorMessage = "The Seerr server address is invalid."
            return
        }
        let mediaServerURL = mediaServerHost.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
            ? nil
            : serverURL(
                scheme: mediaServerScheme,
                host: mediaServerHost,
                port: mediaServerPort
            )
        isConnecting = true
        let serverUser = sameCredentials ? seerrUsername : mediaServerUsername
        let serverPassword = sameCredentials ? seerrPassword : mediaServerPassword
        let credentials = ProfileCredentials(
            seerrLoginMode: loginMode,
            seerrUsername: seerrUsername,
            seerrPassword: seerrPassword,
            mediaServerUsername: serverUser,
            mediaServerPassword: serverPassword
        )
        Task {
            do {
                try await app.createProfile(
                    name: profileName,
                    seerrURL: seerrURL,
                    mediaServerURL: mediaServerURL,
                    avatarIndex: avatarIndex,
                    credentials: credentials
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isConnecting = false
            }
        }
    }

    private func serverURL(scheme: String, host: String, port: String) -> URL? {
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHost.contains("://"), let pasted = URL(string: cleanHost) {
            cleanHost = pasted.host ?? cleanHost
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = cleanHost
        components.port = port.isEmpty ? nil : Int(port)
        return components.url
    }
}

private struct ServerAddressFields: View {
    @Binding var scheme: String
    @Binding var host: String
    @Binding var port: String
    let example: String

    var body: some View {
        Picker("Protocol", selection: $scheme) {
            Text("HTTPS").tag("https")
            Text("HTTP").tag("http")
        }
        .pickerStyle(.segmented)
        TextField("Domain or IP address", text: $host, prompt: Text(example))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        TextField("Custom port (optional)", text: $port)
    }
}

struct ProfileAvatar: View {
    let index: Int
    let size: CGFloat

    private let colors: [[Color]] = [
        [SeerrPlayTheme.magenta, SeerrPlayTheme.violet],
        [SeerrPlayTheme.violet, SeerrPlayTheme.cyan],
        [.orange, .pink],
        [.indigo, .purple],
        [.green, .cyan],
        [.red, .orange],
        [.blue, .indigo],
        [.mint, .teal],
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(
                    LinearGradient(
                        colors: colors[index % colors.count],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: ["person.fill", "star.fill", "bolt.fill", "moon.fill"][index % 4])
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
        }
        .frame(width: size, height: size)
    }
}
