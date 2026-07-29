import Foundation

struct PlexConnectionResult: Sendable {
    let token: String
    let serverURL: URL
    let machineIdentifier: String
    let serverName: String
}

actor PlexService: MediaServerService {
    private let client: APIClient
    private let baseURL: URL
    private let deviceID: String
    private let token: String
    private let machineIdentifier: String
    private let serverName: String
    private var durations: [String: Int] = [:]

    init(
        baseURL: URL,
        deviceID: String,
        token: String,
        machineIdentifier: String,
        serverName: String,
        client: APIClient = APIClient()
    ) {
        self.baseURL = baseURL
        self.deviceID = deviceID
        self.token = token
        self.machineIdentifier = machineIdentifier
        self.serverName = serverName
        self.client = client
    }

    static func link(
        deviceID: String,
        onCode: @MainActor @Sendable (String) -> Void
    ) async throws -> PlexConnectionResult {
        let client = APIClient()
        let plexURL = URL(string: "https://plex.tv")!
        let headers = plexHeaders(deviceID: deviceID)
        let pinResponse = try await client.request(
            baseURL: plexURL,
            path: "api/v2/pins",
            method: "POST",
            query: ["strong": "true"],
            headers: headers
        )
        let pin = try pinResponse.json
        let pinID = pin.int("id")
        let code = pin.string("code") ?? ""
        guard pinID > 0, !code.isEmpty else {
            throw AppError.invalidResponse("Plex did not return a link code.")
        }
        await onCode(code)

        let deadline = Date().addingTimeInterval(180)
        var token = ""
        while Date() < deadline, token.isEmpty {
            try await Task.sleep(for: .seconds(2))
            let response = try await client.request(
                baseURL: plexURL,
                path: "api/v2/pins/\(pinID)",
                headers: headers
            )
            token = (try response.json).string("authToken") ?? ""
        }
        guard !token.isEmpty else {
            throw AppError.invalidResponse("Plex linking timed out.")
        }

        let resources = try await client.request(
            baseURL: plexURL,
            path: "api/v2/resources",
            query: ["includeHttps": "1", "includeRelay": "1"],
            headers: headers.merging(["X-Plex-Token": token]) { _, new in new }
        )
        guard let values = try JSONSerialization.jsonObject(with: resources.data) as? [JSONObject]
        else {
            throw AppError.invalidResponse("Plex returned invalid server resources.")
        }
        let servers = values.filter {
            ($0.string("provides") ?? "").split(separator: ",").contains("server")
        }
        for server in servers {
            let connections = server.objects("connections")
            let selected = connections.first {
                $0.string("uri")?.hasPrefix("https://") == true
                    && !$0.bool("relay")
                    && !$0.bool("local")
            } ?? connections.first {
                $0.string("uri")?.hasPrefix("https://") == true && !$0.bool("relay")
            } ?? connections.first { !$0.bool("relay") } ?? connections.first
            if let uri = selected?.string("uri").flatMap(URL.init(string:)) {
                return PlexConnectionResult(
                    token: token,
                    serverURL: uri,
                    machineIdentifier: server.string("clientIdentifier") ?? "",
                    serverName: server.string("name") ?? "Plex"
                )
            }
        }
        throw AppError.invalidResponse("No accessible Plex Media Server was found.")
    }

    func currentSession() throws -> MediaServerSession {
        try MediaServerSession(json: [
            "AccessToken": token,
            "User": ["Id": machineIdentifier, "Name": serverName],
        ])
    }

    func resume(limit: Int = 25) async throws -> [MediaServerItem] {
        try await items(
            path: "hubs/home/continueWatching",
            query: containerQuery(limit: limit)
        )
    }

    func nextUp(limit: Int = 25) async throws -> [MediaServerItem] {
        try await items(path: "library/onDeck", query: containerQuery(limit: limit))
    }

    func library(search: String = "", limit: Int = 300) async throws -> [MediaServerItem] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return try await items(
                path: "hubs/search",
                query: containerQuery(limit: limit).merging(["query": trimmed]) { _, new in new }
            )
        }
        return try await items(path: "library/all", query: containerQuery(limit: limit))
    }

    func details(id: String) async throws -> MediaServerItem {
        let response = try await request(path: "library/metadata/\(id)")
        guard let item = metadata(try response.json).first else {
            throw AppError.noPlayableMedia
        }
        return plexItem(item)
    }

    func resolve(media: MediaItem) async throws -> MediaServerItem {
        if let id = media.mediaInfo?.mediaServerID {
            return try await playableItem(id: id)
        }
        let candidates = try await library(search: media.title, limit: 25)
        if let exact = candidates.first(where: { $0.providerIDs["tmdb"] == String(media.id) }) {
            return try await playableItem(id: exact.id)
        }
        guard let match = candidates.first(where: {
            $0.name.compare(
                media.title,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }) else {
            throw AppError.noPlayableMedia
        }
        return try await playableItem(id: match.id)
    }

    func imageURL(for item: MediaServerItem, backdrop: Bool = false) -> URL? {
        let path = backdrop ? item.backdropImagePath : item.primaryImagePath
        guard let path else { return nil }
        return url(path: path, query: ["X-Plex-Token": token])
    }

    func playback(for requestedItem: MediaServerItem) async throws -> PlaybackSource {
        let item = try await playableItem(id: requestedItem.id)
        let response = try await request(
            path: "library/metadata/\(item.id)",
            query: ["includeGuids": "1", "includeUserState": "1"]
        )
        guard let raw = metadata(try response.json).first,
              let media = raw.objects("Media").first,
              let part = media.objects("Part").first,
              let partPath = part.string("key")
        else {
            throw AppError.noPlayableMedia
        }
        let duration = raw.int("duration")
        durations[item.id] = duration
        let directContainers = ["mp4", "m4v", "mov", "mpegts", "ts"]
        let container = part.string("container")?.lowercased() ?? ""
        let playbackURL: URL
        let method: String
        if directContainers.contains(container),
           let direct = url(path: partPath, query: ["X-Plex-Token": token])
        {
            playbackURL = direct
            method = "DirectPlay"
        } else {
            let metadataPath = raw.string("key") ?? "/library/metadata/\(item.id)"
            guard let transcoded = url(
                path: "video/:/transcode/universal/start.m3u8",
                query: [
                    "path": metadataPath,
                    "mediaIndex": "0",
                    "partIndex": "0",
                    "protocol": "hls",
                    "directPlay": "0",
                    "directStream": "1",
                    "fastSeek": "1",
                    "session": UUID().uuidString.lowercased(),
                    "X-Plex-Token": token,
                    "X-Plex-Client-Identifier": deviceID,
                    "X-Plex-Product": "SeerrPlay",
                ]
            ) else {
                throw AppError.invalidURL
            }
            playbackURL = transcoded
            method = "Transcode"
        }
        return PlaybackSource(
            item: item,
            mediaSourceID: part.string("id") ?? item.id,
            playSessionID: UUID().uuidString.lowercased(),
            url: playbackURL,
            headers: Self.plexHeaders(deviceID: deviceID)
                .merging(["X-Plex-Token": token]) { _, new in new },
            startPosition: Double(item.userData.playbackPositionTicks) / 10_000_000,
            playMethod: method
        )
    }

    func report(
        event: String,
        source: PlaybackSource,
        position: TimeInterval,
        paused: Bool
    ) async {
        let state: String
        if event.hasSuffix("Stopped") {
            state = "stopped"
        } else {
            state = paused ? "paused" : "playing"
        }
        _ = try? await request(
            path: ":/timeline",
            query: [
                "ratingKey": source.item.id,
                "key": "/library/metadata/\(source.item.id)",
                "state": state,
                "time": String(Int(max(position, 0) * 1000)),
                "duration": String(durations[source.item.id] ?? 0),
                "X-Plex-Session-Identifier": source.playSessionID,
            ]
        )
    }

    private func playableItem(id: String) async throws -> MediaServerItem {
        let item = try await details(id: id)
        guard item.type == "Series" else { return item }
        let episodes = try await items(
            path: "library/metadata/\(id)/allLeaves",
            query: containerQuery(limit: 1)
        )
        guard let episode = episodes.first else { throw AppError.noPlayableMedia }
        return episode
    }

    private func items(path: String, query: [String: String]) async throws -> [MediaServerItem] {
        let response = try await request(path: path, query: query)
        return metadata(try response.json).map(plexItem)
    }

    private func request(
        path: String,
        method: String = "GET",
        query: [String: String] = [:]
    ) async throws -> APIResponse {
        try await client.request(
            baseURL: baseURL,
            path: path,
            method: method,
            query: query.mapValues(Optional.some),
            headers: Self.plexHeaders(deviceID: deviceID)
                .merging(["X-Plex-Token": token]) { _, new in new }
        )
    }

    private func metadata(_ json: JSONObject) -> [JSONObject] {
        let container = json.object("MediaContainer") ?? json
        let direct = container.objects("Metadata")
        let hubs = container.objects("Hub").flatMap { $0.objects("Metadata") }
        return direct + hubs
    }

    private func plexItem(_ json: JSONObject) -> MediaServerItem {
        let type = switch json.string("type") {
        case "movie": "Movie"
        case "show": "Series"
        case "episode": "Episode"
        default: "Video"
        }
        var providers: [String: String] = [:]
        for guid in json.objects("Guid") {
            guard let value = guid.string("id"),
                  let separator = value.range(of: "://")
            else { continue }
            providers[String(value[..<separator.lowerBound])] =
                String(value[separator.upperBound...])
        }
        let offset = Int64(json.int("viewOffset")) * 10_000
        let lastPlayed = json.optionalInt("lastViewedAt").map {
            Date(timeIntervalSince1970: TimeInterval($0))
        }
        return MediaServerItem(
            id: json.string("ratingKey") ?? "",
            name: json.string("title") ?? "Untitled",
            type: type,
            overview: json.string("summary") ?? "",
            runtimeTicks: json.optionalInt64("duration").map { $0 * 10_000 },
            productionYear: json.optionalInt("year"),
            officialRating: json.string("contentRating"),
            seriesName: json.string("grandparentTitle"),
            seasonNumber: json.optionalInt("parentIndex"),
            episodeNumber: json.optionalInt("index"),
            providerIDs: providers,
            primaryImagePath: json.string("thumb"),
            backdropImagePath: json.string("art"),
            userData: MediaServerUserData(
                playbackPositionTicks: offset,
                played: json.int("viewCount") > 0,
                lastPlayedDate: lastPlayed
            )
        )
    }

    private func containerQuery(limit: Int) -> [String: String] {
        [
            "X-Plex-Container-Start": "0",
            "X-Plex-Container-Size": String(limit),
        ]
    }

    private func url(path: String, query: [String: String]) -> URL? {
        var result = baseURL
        for component in path.split(separator: "/") {
            result.appendPathComponent(String(component))
        }
        var components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components?.url
    }

    private static func plexHeaders(deviceID: String) -> [String: String] {
        [
            "Accept": "application/json",
            "X-Plex-Product": "SeerrPlay",
            "X-Plex-Client-Identifier": deviceID,
            "X-Plex-Platform": "tvOS",
            "X-Plex-Version": "1.0.0",
        ]
    }
}
