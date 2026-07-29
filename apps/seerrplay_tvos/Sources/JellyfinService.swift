import Foundation

actor JellyfinService: MediaServerService {
    private let client: APIClient
    private let baseURL: URL
    private let deviceID: String
    private var token: String
    private var userID: String
    private var userName: String

    init(
        baseURL: URL,
        deviceID: String,
        token: String = "",
        userID: String = "",
        userName: String = "",
        client: APIClient = APIClient()
    ) {
        self.baseURL = baseURL
        self.deviceID = deviceID
        self.token = token
        self.userID = userID
        self.userName = userName
        self.client = client
    }

    func restore(token: String, userID: String, userName: String) {
        self.token = token
        self.userID = userID
        self.userName = userName
    }

    func currentSession() throws -> MediaServerSession {
        guard !token.isEmpty, !userID.isEmpty else { throw AppError.notAuthenticated }
        return try MediaServerSession(json: [
            "AccessToken": token,
            "User": ["Id": userID, "Name": userName],
        ])
    }

    func authenticate(username: String, password: String) async throws -> MediaServerSession {
        let body = try JSONSerialization.data(withJSONObject: [
            "Username": username.trimmingCharacters(in: .whitespacesAndNewlines),
            "Pw": password,
        ])
        let response = try await client.request(
            baseURL: baseURL,
            path: "Users/AuthenticateByName",
            method: "POST",
            body: body,
            headers: authorizationHeaders(token: nil)
        )
        let session = try MediaServerSession(json: response.json)
        token = session.token
        userID = session.user.id
        userName = session.user.name
        return session
    }

    func resume(limit: Int = 25) async throws -> [MediaServerItem] {
        try await items(
            path: "Users/\(requiredUserID())/Items/Resume",
            query: commonItemQuery(limit: limit).merging([
                "MediaTypes": "Video",
                "IncludeItemTypes": "Movie,Episode",
            ]) { _, new in new }
        )
    }

    func nextUp(limit: Int = 25) async throws -> [MediaServerItem] {
        try await items(
            path: "Shows/NextUp",
            query: [
                "UserId": requiredUserID(),
                "StartIndex": "0",
                "Limit": String(limit),
                "Fields": itemFields,
                "EnableUserData": "true",
                "EnableImageTypes": "Primary,Backdrop,Thumb",
            ]
        )
    }

    func library(search: String = "", limit: Int = 300) async throws -> [MediaServerItem] {
        var query = commonItemQuery(limit: limit)
        query["IncludeItemTypes"] = "Movie,Series,Video"
        query["SortBy"] = "SortName"
        query["SortOrder"] = "Ascending"
        if !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query["SearchTerm"] = search.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return try await items(path: "Users/\(requiredUserID())/Items", query: query)
    }

    func details(id: String) async throws -> MediaServerItem {
        let response = try await authenticated(path: "Users/\(requiredUserID())/Items/\(id)")
        return MediaServerItem(json: try response.json)
    }

    func playableItem(id: String) async throws -> MediaServerItem {
        let item = try await details(id: id)
        guard item.type == "Series" else { return item }
        let next = try await items(
            path: "Shows/NextUp",
            query: [
                "UserId": requiredUserID(),
                "SeriesId": item.id,
                "Limit": "1",
                "Fields": itemFields,
                "EnableUserData": "true",
            ]
        )
        if let episode = next.first { return episode }
        let episodes = try await items(
            path: "Users/\(requiredUserID())/Items",
            query: [
                "ParentId": item.id,
                "Recursive": "true",
                "IncludeItemTypes": "Episode",
                "SortBy": "ParentIndexNumber,IndexNumber",
                "SortOrder": "Ascending",
                "Limit": "1",
                "Fields": itemFields,
                "EnableUserData": "true",
            ]
        )
        guard let episode = episodes.first else { throw AppError.noPlayableMedia }
        return episode
    }

    func resolve(media: MediaItem) async throws -> MediaServerItem {
        if let id = media.mediaInfo?.mediaServerID {
            return try await playableItem(id: id)
        }
        let candidates = try await library(search: media.title, limit: 25)
        let tmdbID = String(media.id)
        if let exact = candidates.first(where: { $0.providerIDs["Tmdb"] == tmdbID }) {
            return try await playableItem(id: exact.id)
        }
        guard let titleMatch = candidates.first(where: {
            $0.name.compare(media.title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            throw AppError.noPlayableMedia
        }
        return try await playableItem(id: titleMatch.id)
    }

    func imageURL(for item: MediaServerItem, backdrop: Bool = false) -> URL? {
        let tag = backdrop ? item.backdropImageTag : item.primaryImageTag
        guard let tag else { return nil }
        let type = backdrop ? "Backdrop" : "Primary"
        return url(
            path: "Items/\(item.id)/Images/\(type)",
            query: [
                "tag": tag,
                "quality": "90",
                "maxWidth": backdrop ? "1600" : "500",
            ]
        )
    }

    func playback(for requestedItem: MediaServerItem) async throws -> PlaybackSource {
        let item = try await playableItem(id: requestedItem.id)
        let startTicks = item.userData.playbackPositionTicks
        let accessToken = try requiredToken()
        let currentUserID = try requiredUserID()
        let response = try await authenticated(
            path: "Items/\(item.id)/PlaybackInfo",
            method: "POST",
            query: [
                "UserId": requiredUserID(),
                "StartTimeTicks": String(startTicks),
                "MaxStreamingBitrate": "120000000",
                "EnableDirectPlay": "true",
                "EnableDirectStream": "true",
                "EnableTranscoding": "true",
                "IsPlayback": "true",
                "AutoOpenLiveStream": "true",
            ],
            body: playbackBody(startTicks: startTicks)
        )
        let json = try response.json
        guard let source = json.objects("MediaSources").first else {
            throw AppError.noPlayableMedia
        }
        let sourceID = source.string("Id") ?? ""
        let transcodingURL = source.string("TranscodingUrl")
        let supportsDirectPlay = source.bool("SupportsDirectPlay")
        let container = source.string("Container")?.lowercased() ?? ""
        let directContainers = ["mp4", "m4v", "mov", "mpegts", "ts"]
        let playbackURL: URL
        let method: String

        if supportsDirectPlay, directContainers.contains(container) {
            guard let direct = url(
                path: "Videos/\(item.id)/stream",
                query: [
                    "Static": "true",
                    "MediaSourceId": sourceID,
                    "api_key": accessToken,
                ]
            ) else {
                throw AppError.invalidURL
            }
            playbackURL = direct
            method = "DirectPlay"
        } else if let transcodingURL,
                  let relative = URLComponents(string: transcodingURL)
        {
            guard let transcoded = merge(relative: relative, apiKey: accessToken) else {
                throw AppError.invalidURL
            }
            playbackURL = transcoded
            method = "Transcode"
        } else {
            guard let hls = url(
                path: "Videos/\(item.id)/master.m3u8",
                query: [
                    "UserId": currentUserID,
                    "DeviceId": deviceID,
                    "MediaSourceId": sourceID,
                    "VideoCodec": "h264,hevc",
                    "AudioCodec": "aac,ac3,eac3,mp3",
                    "MaxStreamingBitrate": "120000000",
                    "SegmentContainer": "ts",
                    "MinSegments": "2",
                    "BreakOnNonKeyFrames": "true",
                    "api_key": accessToken,
                ]
            ) else {
                throw AppError.invalidURL
            }
            playbackURL = hls
            method = "Transcode"
        }

        return PlaybackSource(
            item: item,
            mediaSourceID: sourceID,
            playSessionID: json.string("PlaySessionId") ?? UUID().uuidString,
            url: playbackURL,
            headers: authorizationHeaders(token: accessToken),
            startPosition: Double(startTicks) / 10_000_000,
            playMethod: method
        )
    }

    func report(
        event: String,
        source: PlaybackSource,
        position: TimeInterval,
        paused: Bool
    ) async {
        let ticks = Int64(max(position, 0) * 10_000_000)
        let body: JSONObject = [
            "ItemId": source.item.id,
            "MediaSourceId": source.mediaSourceID,
            "PlaySessionId": source.playSessionID,
            "PositionTicks": ticks,
            "IsPaused": paused,
            "PlayMethod": source.playMethod,
        ]
        _ = try? await authenticated(path: "Sessions/\(event)", method: "POST", body: body)
    }

    private var itemFields: String {
        "Overview,ProviderIds,PrimaryImageAspectRatio"
    }

    private func commonItemQuery(limit: Int) -> [String: String] {
        [
            "StartIndex": "0",
            "Limit": String(limit),
            "Recursive": "true",
            "Fields": itemFields,
            "EnableUserData": "true",
            "EnableImageTypes": "Primary,Backdrop,Thumb",
            "EnableTotalRecordCount": "true",
        ]
    }

    private func items(path: String, query: [String: String]) async throws -> [MediaServerItem] {
        let response = try await authenticated(
            path: path,
            query: query.mapValues(Optional.some)
        )
        return try response.json.objects("Items").map(MediaServerItem.init)
    }

    private func authenticated(
        path: String,
        method: String = "GET",
        query: [String: String?] = [:],
        body: JSONObject? = nil
    ) async throws -> APIResponse {
        let bodyData = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        return try await client.request(
            baseURL: baseURL,
            path: path,
            method: method,
            query: query,
            body: bodyData,
            headers: authorizationHeaders(token: requiredToken())
        )
    }

    private func authorizationHeaders(token: String?) -> [String: String] {
        var parameters = [
            #"Client="SeerrPlay""#,
            #"Device="Apple TV""#,
            #"DeviceId="\#(deviceID)""#,
            #"Version="1.0.0""#,
        ]
        if let token, !token.isEmpty {
            parameters.append(#"Token="\#(token)""#)
        }
        var headers = ["Authorization": "MediaBrowser \(parameters.joined(separator: ", "))"]
        if let token, !token.isEmpty {
            headers["X-Emby-Token"] = token
        }
        return headers
    }

    private func playbackBody(startTicks: Int64) -> JSONObject {
        [
            "UserId": userID,
            "StartTimeTicks": startTicks,
            "MaxStreamingBitrate": 120_000_000,
            "EnableDirectPlay": true,
            "EnableDirectStream": true,
            "EnableTranscoding": true,
            "AllowVideoStreamCopy": true,
            "AllowAudioStreamCopy": true,
            "DeviceProfile": [
                "Name": "SeerrPlay tvOS",
                "MaxStreamingBitrate": 120_000_000,
                "DirectPlayProfiles": [
                    [
                        "Container": "mp4,m4v,mov,mpegts",
                        "Type": "Video",
                        "VideoCodec": "h264,hevc",
                        "AudioCodec": "aac,mp3,ac3,eac3,alac,flac",
                    ],
                ],
                "TranscodingProfiles": [
                    [
                        "Container": "ts",
                        "Type": "Video",
                        "Protocol": "hls",
                        "VideoCodec": "h264,hevc",
                        "AudioCodec": "aac,ac3,eac3",
                        "Context": "Streaming",
                        "EstimateContentLength": false,
                        "EnableMpegtsM2TsMode": false,
                        "BreakOnNonKeyFrames": true,
                    ],
                ],
                "SubtitleProfiles": [
                    ["Format": "vtt", "Method": "Hls"],
                    ["Format": "srt", "Method": "Encode"],
                    ["Format": "ass", "Method": "Encode"],
                    ["Format": "ssa", "Method": "Encode"],
                    ["Format": "pgssub", "Method": "Encode"],
                ],
            ],
        ]
    }

    private func requiredToken() throws -> String {
        guard !token.isEmpty else { throw AppError.notAuthenticated }
        return token
    }

    private func requiredUserID() throws -> String {
        guard !userID.isEmpty else { throw AppError.notAuthenticated }
        return userID
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

    private func merge(relative: URLComponents, apiKey: String) -> URL? {
        var result = baseURL
        for component in relative.path.split(separator: "/") {
            result.appendPathComponent(String(component))
        }
        var components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        var query = relative.queryItems ?? []
        if !query.contains(where: { $0.name == "api_key" }) {
            query.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        components?.queryItems = query
        return components?.url
    }
}
