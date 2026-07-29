import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum Phase {
        case launching
        case profileSelection
        case connecting
        case ready
    }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var profiles: [ServerProfile] = []
    @Published private(set) var activeProfile: ServerProfile?
    @Published private(set) var seerrDisplayName = ""
    @Published private(set) var mediaServerDisplayName = ""
    @Published private(set) var plexLinkCode: String?
    @Published var globalError: String?

    private let defaults: UserDefaults
    private var seerr: SeerrService?
    private var mediaServer: (any MediaServerService)?
    private var sessions: StoredSessions?

    let language: String
    let region: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let locale = Locale.autoupdatingCurrent
        language = locale.language.languageCode?.identifier ?? "en"
        region = locale.region?.identifier ?? "FR"
    }

    func bootstrap() async {
        profiles = loadProfiles()
        guard let activeID = defaults.string(forKey: "activeProfileID"),
              let id = UUID(uuidString: activeID),
              let profile = profiles.first(where: { $0.id == id })
        else {
            phase = .profileSelection
            return
        }
        await activate(profile)
    }

    func activate(_ profile: ServerProfile) async {
        phase = .connecting
        globalError = nil
        plexLinkCode = nil
        activeProfile = profile
        let credentials = KeychainStore.load(
            ProfileCredentials.self,
            account: credentialsAccount(profile.id)
        )
        let stored = KeychainStore.load(
            StoredSessions.self,
            account: sessionsAccount(profile.id)
        )
        let deviceID = stored?.deviceID ?? UUID().uuidString.lowercased()
        let seerrService = SeerrService(
            baseURL: profile.seerrURL,
            sessionCookie: stored?.seerrCookie ?? ""
        )
        seerr = seerrService
        mediaServer = makeMediaServer(
            profile: profile,
            stored: stored,
            deviceID: deviceID
        )

        do {
            if let stored, let mediaServer {
                async let seerrUser = seerrService.me()
                async let restoredServerSession = mediaServer.currentSession()
                let (user, serverSession) = try await (
                    seerrUser,
                    restoredServerSession
                )
                applySession(user: user, mediaServer: serverSession, stored: stored)
            } else if let credentials {
                try await authenticate(
                    profile: profile,
                    credentials: credentials,
                    deviceID: deviceID,
                    persist: true
                )
            } else {
                throw AppError.notAuthenticated
            }
            defaults.set(profile.id.uuidString, forKey: "activeProfileID")
            phase = .ready
        } catch {
            if let credentials {
                do {
                    try await authenticate(
                        profile: profile,
                        credentials: credentials,
                        deviceID: deviceID,
                        persist: true
                    )
                    defaults.set(profile.id.uuidString, forKey: "activeProfileID")
                    phase = .ready
                    return
                } catch {
                    globalError = error.localizedDescription
                }
            } else {
                globalError = error.localizedDescription
            }
            phase = .profileSelection
        }
    }

    func createProfile(
        name: String,
        seerrURL: URL,
        mediaServerURL fallbackMediaServerURL: URL?,
        avatarIndex: Int,
        credentials: ProfileCredentials
    ) async throws {
        phase = .connecting
        globalError = nil
        plexLinkCode = nil
        let id = UUID()
        let deviceID = id.uuidString.lowercased()
        let seerrService = SeerrService(baseURL: seerrURL)
        seerr = seerrService
        let configuration = try await seerrService.publicConfiguration()

        var effectiveServerURL = configuration.mediaServerURL ?? fallbackMediaServerURL
        var plexConnection: PlexConnectionResult?
        if configuration.mediaServerType == .plex {
            let linked = try await PlexService.link(deviceID: deviceID) { [weak self] code in
                self?.plexLinkCode = code
            }
            plexConnection = linked
            effectiveServerURL = linked.serverURL
        }
        guard let effectiveServerURL else {
            phase = .profileSelection
            throw AppError.invalidResponse(
                "Seerr did not publish the media server address. Enter it manually."
            )
        }

        let profile = ServerProfile(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            seerrURL: seerrURL,
            mediaServerURL: effectiveServerURL,
            mediaServerType: configuration.mediaServerType,
            avatarIndex: avatarIndex
        )
        activeProfile = profile
        if let plexConnection {
            // Plex linking returns both the user token and the concrete server
            // connection. Jellyfin and Emby instead share MediaBrowser APIs,
            // so one service implementation can be configured for either.
            mediaServer = PlexService(
                baseURL: plexConnection.serverURL,
                deviceID: deviceID,
                token: plexConnection.token,
                machineIdentifier: plexConnection.machineIdentifier,
                serverName: plexConnection.serverName
            )
        } else {
            mediaServer = JellyfinService(
                baseURL: effectiveServerURL,
                deviceID: deviceID
            )
        }

        do {
            try await authenticate(
                profile: profile,
                credentials: credentials,
                deviceID: deviceID,
                persist: false,
                plexConnection: plexConnection
            )
            profiles.append(profile)
            saveProfiles()
            try KeychainStore.save(credentials, account: credentialsAccount(profile.id))
            if let sessions {
                try KeychainStore.save(sessions, account: sessionsAccount(profile.id))
            }
            defaults.set(profile.id.uuidString, forKey: "activeProfileID")
            plexLinkCode = nil
            phase = .ready
        } catch {
            phase = .profileSelection
            activeProfile = nil
            seerr = nil
            mediaServer = nil
            throw error
        }
    }

    func showProfileSelection() {
        phase = .profileSelection
    }

    func deleteProfile(_ profile: ServerProfile) {
        profiles.removeAll { $0.id == profile.id }
        KeychainStore.delete(account: credentialsAccount(profile.id))
        KeychainStore.delete(account: sessionsAccount(profile.id))
        if activeProfile?.id == profile.id {
            activeProfile = nil
            seerr = nil
            mediaServer = nil
            sessions = nil
            defaults.removeObject(forKey: "activeProfileID")
            phase = .profileSelection
        }
        saveProfiles()
    }

    func loadHome() async throws -> HomeContent {
        guard let seerr, let mediaServer, let sessions else {
            throw AppError.notAuthenticated
        }
        async let resume = mediaServer.resume(limit: 25)
        async let nextUp = mediaServer.nextUp(limit: 25)
        async let trending = seerr.trending(language: language)
        async let movies = seerr.discover(kind: .movie, language: language)
        async let shows = seerr.discover(kind: .tv, language: language)
        async let requests = seerr.requests(userID: sessions.seerrUserID, take: 40)
        let values = try await (resume, nextUp, trending, movies, shows, requests)
        let availableRequests = values.5.filter {
            $0.media.mediaInfo?.availability == .available
                || $0.media.mediaInfo?.availability == .partiallyAvailable
        }
        return HomeContent(
            continueWatching: mergePlayback(resume: values.0, nextUp: values.1),
            availableRequests: availableRequests,
            trending: values.2,
            popularMovies: values.3,
            popularShows: values.4
        )
    }

    func search(_ query: String) async throws -> [MediaItem] {
        guard let seerr else { throw AppError.notAuthenticated }
        return try await seerr.search(query: query, language: language)
    }

    func discover(_ kind: MediaKind) async throws -> [MediaItem] {
        guard let seerr else { throw AppError.notAuthenticated }
        return try await seerr.discover(kind: kind, language: language)
    }

    func library(search: String = "") async throws -> [MediaServerItem] {
        guard let mediaServer else { throw AppError.notAuthenticated }
        return try await mediaServer.library(search: search, limit: 300)
    }

    func requests() async throws -> [RequestItem] {
        guard let seerr, let sessions else { throw AppError.notAuthenticated }
        return try await seerr.requests(userID: sessions.seerrUserID)
    }

    func mediaDetails(_ item: MediaItem) async throws -> MediaDetails {
        guard let seerr else { throw AppError.notAuthenticated }
        return try await seerr.details(for: item, language: language, region: region)
    }

    func personDetails(_ id: Int) async throws -> PersonDetails {
        guard let seerr else { throw AppError.notAuthenticated }
        return try await seerr.person(id: id, language: language)
    }

    func createRequest(_ item: MediaItem) async throws {
        guard let seerr else { throw AppError.notAuthenticated }
        try await seerr.createRequest(for: item)
    }

    func deleteRequest(_ id: Int) async throws {
        guard let seerr else { throw AppError.notAuthenticated }
        try await seerr.deleteRequest(id: id)
    }

    func mediaServerDetails(_ item: MediaServerItem) async throws -> MediaServerItem {
        guard let mediaServer else { throw AppError.notAuthenticated }
        return try await mediaServer.details(id: item.id)
    }

    func mediaServerImage(_ item: MediaServerItem, backdrop: Bool = false) async -> URL? {
        guard let mediaServer else { return nil }
        return await mediaServer.imageURL(for: item, backdrop: backdrop)
    }

    func playback(for item: MediaServerItem) async throws -> PlaybackSource {
        guard let mediaServer else { throw AppError.notAuthenticated }
        return try await mediaServer.playback(for: item)
    }

    func playback(for item: MediaItem) async throws -> PlaybackSource {
        guard let mediaServer else { throw AppError.notAuthenticated }
        let resolved = try await mediaServer.resolve(media: item)
        return try await mediaServer.playback(for: resolved)
    }

    func reportPlayback(
        event: String,
        source: PlaybackSource,
        position: TimeInterval,
        paused: Bool
    ) async {
        guard let mediaServer else { return }
        await mediaServer.report(
            event: event,
            source: source,
            position: position,
            paused: paused
        )
    }

    private func authenticate(
        profile: ServerProfile,
        credentials: ProfileCredentials,
        deviceID: String,
        persist: Bool,
        plexConnection initialPlexConnection: PlexConnectionResult? = nil
    ) async throws {
        guard let seerr else { throw AppError.notAuthenticated }
        let serverSession: MediaServerSession
        var plexConnection = initialPlexConnection
        if profile.mediaServerType == .plex {
            if plexConnection == nil {
                plexConnection = try await PlexService.link(deviceID: deviceID) {
                    [weak self] code in
                    self?.plexLinkCode = code
                }
            }
            guard let plexConnection else { throw AppError.notAuthenticated }
            let service = PlexService(
                baseURL: plexConnection.serverURL,
                deviceID: deviceID,
                token: plexConnection.token,
                machineIdentifier: plexConnection.machineIdentifier,
                serverName: plexConnection.serverName
            )
            mediaServer = service
            serverSession = try await service.currentSession()
        } else {
            let service: JellyfinService
            if let current = mediaServer as? JellyfinService {
                service = current
            } else {
                service = JellyfinService(
                    baseURL: profile.mediaServerURL,
                    deviceID: deviceID
                )
                mediaServer = service
            }
            serverSession = try await service.authenticate(
                username: credentials.mediaServerUsername,
                password: credentials.mediaServerPassword
            )
        }

        let user = try await seerr.login(
            mode: credentials.seerrLoginMode,
            username: credentials.seerrUsername,
            password: credentials.seerrPassword,
            mediaServerType: profile.mediaServerType,
            plexToken: plexConnection?.token
        )
        let stored = StoredSessions(
            seerrCookie: await seerr.currentCookie(),
            seerrUserID: user.id,
            seerrDisplayName: user.displayName,
            mediaServerToken: serverSession.token,
            mediaServerUserID: serverSession.user.id,
            mediaServerDisplayName: serverSession.user.name,
            mediaServerID: plexConnection?.machineIdentifier ?? serverSession.user.id,
            deviceID: deviceID
        )
        applySession(user: user, mediaServer: serverSession, stored: stored)
        if persist {
            try KeychainStore.save(stored, account: sessionsAccount(profile.id))
        }
    }

    private func makeMediaServer(
        profile: ServerProfile,
        stored: StoredSessions?,
        deviceID: String
    ) -> (any MediaServerService)? {
        guard let stored else { return nil }
        if profile.mediaServerType == .plex {
            return PlexService(
                baseURL: profile.mediaServerURL,
                deviceID: deviceID,
                token: stored.mediaServerToken,
                machineIdentifier: stored.mediaServerID,
                serverName: stored.mediaServerDisplayName
            )
        }
        return JellyfinService(
            baseURL: profile.mediaServerURL,
            deviceID: deviceID,
            token: stored.mediaServerToken,
            userID: stored.mediaServerUserID,
            userName: stored.mediaServerDisplayName
        )
    }

    private func applySession(
        user: SeerrUser,
        mediaServer: MediaServerSession,
        stored: StoredSessions
    ) {
        sessions = stored
        seerrDisplayName = user.displayName
        mediaServerDisplayName = mediaServer.user.name
    }

    private func mergePlayback(
        resume: [MediaServerItem],
        nextUp: [MediaServerItem]
    ) -> [MediaServerItem] {
        var seen = Set<String>()
        return (resume + nextUp)
            .sorted {
                ($0.userData.lastPlayedDate ?? .distantPast)
                    > ($1.userData.lastPlayedDate ?? .distantPast)
            }
            .filter { seen.insert($0.id).inserted }
    }

    private func loadProfiles() -> [ServerProfile] {
        guard let data = defaults.data(forKey: "profiles") else { return [] }
        return (try? JSONDecoder().decode([ServerProfile].self, from: data)) ?? []
    }

    private func saveProfiles() {
        defaults.set(try? JSONEncoder().encode(profiles), forKey: "profiles")
    }

    private func credentialsAccount(_ id: UUID) -> String {
        "profile.\(id.uuidString).credentials"
    }

    private func sessionsAccount(_ id: UUID) -> String {
        "profile.\(id.uuidString).sessions"
    }
}

struct HomeContent: Sendable {
    let continueWatching: [MediaServerItem]
    let availableRequests: [RequestItem]
    let trending: [MediaItem]
    let popularMovies: [MediaItem]
    let popularShows: [MediaItem]
}
