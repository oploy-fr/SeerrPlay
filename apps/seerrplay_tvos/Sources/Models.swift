import Foundation

enum MediaKind: String, Codable, Sendable {
    case movie
    case tv
    case person
    case unknown

    init(_ value: Any?) {
        self = MediaKind(rawValue: String(describing: value ?? "").lowercased()) ?? .unknown
    }
}

enum Availability: Int, Codable, Sendable {
    case unknown = 0
    case pending = 2
    case processing = 3
    case partiallyAvailable = 4
    case available = 5
    case blocklisted = 6
    case deleted = 7

    var title: String {
        switch self {
        case .pending: NSLocalizedString("Pending", comment: "")
        case .processing: NSLocalizedString("Downloading", comment: "")
        case .partiallyAvailable: NSLocalizedString("Partially available", comment: "")
        case .available: NSLocalizedString("Available", comment: "")
        case .blocklisted: NSLocalizedString("Blocked", comment: "")
        case .deleted: NSLocalizedString("Deleted", comment: "")
        case .unknown: NSLocalizedString("Unavailable", comment: "")
        }
    }
}

enum RequestStatus: Int, Codable, Sendable, CaseIterable {
    case unknown = 0
    case pending = 1
    case approved = 2
    case declined = 3
    case failed = 4
    case completed = 5

    var title: String {
        switch self {
        case .pending: NSLocalizedString("Pending", comment: "")
        case .approved: NSLocalizedString("Approved", comment: "")
        case .declined: NSLocalizedString("Declined", comment: "")
        case .failed: NSLocalizedString("Failed", comment: "")
        case .completed: NSLocalizedString("Available", comment: "")
        case .unknown: NSLocalizedString("Unknown", comment: "")
        }
    }
}

enum MediaServerType: Int, Codable, CaseIterable, Sendable {
    case plex = 1
    case jellyfin = 2
    case emby = 3

    var title: String {
        switch self {
        case .plex: "Plex"
        case .jellyfin: "Jellyfin"
        case .emby: "Emby"
        }
    }
}

struct ServerProfile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var seerrURL: URL
    var mediaServerURL: URL
    var mediaServerType: MediaServerType
    var avatarIndex: Int
}

enum SeerrLoginMode: String, Codable, CaseIterable, Sendable {
    case local
    case mediaServer

    var title: String {
        self == .local
            ? NSLocalizedString("Seerr account", comment: "")
            : NSLocalizedString("Media server account", comment: "")
    }
}

struct ProfileCredentials: Codable, Sendable {
    var seerrLoginMode: SeerrLoginMode
    var seerrUsername: String
    var seerrPassword: String
    var mediaServerUsername: String
    var mediaServerPassword: String
}

struct StoredSessions: Codable, Sendable {
    var seerrCookie: String
    var seerrUserID: Int
    var seerrDisplayName: String
    var mediaServerToken: String
    var mediaServerUserID: String
    var mediaServerDisplayName: String
    var mediaServerID: String
    var deviceID: String
}

struct SeerrUser: Sendable {
    let id: Int
    let displayName: String

    init(json: JSONObject) {
        id = json.int("id")
        displayName = json.string("username")
            ?? json.string("jellyfinUsername")
            ?? json.string("email")
            ?? "Seerr"
    }
}

struct SeerrPublicConfiguration: Sendable {
    let mediaServerType: MediaServerType
    let mediaServerURL: URL?

    init(json: JSONObject) throws {
        guard let type = MediaServerType(rawValue: json.int("mediaServerType"))
        else {
            throw AppError.invalidResponse(
                "Seerr has no supported media server configured."
            )
        }
        mediaServerType = type
        mediaServerURL = json.string("jellyfinExternalHost").flatMap(URL.init(string:))
    }
}

struct MediaInfo: Hashable, Sendable {
    let requestID: Int?
    let jellyfinID: String?
    let jellyfin4KID: String?
    let plexRatingKey: String?
    let plex4KRatingKey: String?
    let availability: Availability

    init?(json: JSONObject?) {
        guard let json else { return nil }
        requestID = json.optionalInt("id")
        jellyfinID = json.string("jellyfinMediaId")
        jellyfin4KID = json.string("jellyfinMediaId4k")
        plexRatingKey = json.string("ratingKey")
        plex4KRatingKey = json.string("ratingKey4k")
        availability = Availability(rawValue: json.int("status")) ?? .unknown
    }

    var mediaServerID: String? {
        plexRatingKey ?? jellyfinID ?? plex4KRatingKey ?? jellyfin4KID
    }
}

struct MediaItem: Identifiable, Hashable, Sendable {
    let id: Int
    let kind: MediaKind
    let title: String
    let overview: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let rating: Double
    let mediaInfo: MediaInfo?

    init(json: JSONObject) {
        id = json.int("id")
        kind = MediaKind(json["mediaType"])
        title = json.string("title")
            ?? json.string("name")
            ?? json.string("originalTitle")
            ?? json.string("originalName")
            ?? "Untitled"
        overview = json.string("overview") ?? ""
        posterPath = json.string("posterPath")
        backdropPath = json.string("backdropPath")
        releaseDate = JSON.date(json.string("releaseDate") ?? json.string("firstAirDate"))
        rating = json.double("voteAverage")
        mediaInfo = MediaInfo(json: json.object("mediaInfo"))
    }

    var posterURL: URL? {
        TMDB.image(path: posterPath, size: "w500")
    }

    var backdropURL: URL? {
        TMDB.image(path: backdropPath, size: "w1280")
    }
}

struct CastMember: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    init(json: JSONObject) {
        id = json.int("id")
        name = json.string("name") ?? ""
        character = json.string("character")
        profilePath = json.string("profilePath")
    }

    var imageURL: URL? {
        TMDB.image(path: profilePath, size: "w300")
    }
}

struct RelatedVideo: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let url: URL?
    let type: String?

    init(json: JSONObject) {
        name = json.string("name") ?? "Trailer"
        url = json.string("url").flatMap(URL.init(string:))
        type = json.string("type")
    }
}

struct MediaDetails: Identifiable, Sendable {
    let id: Int
    let kind: MediaKind
    let title: String
    let originalTitle: String?
    let overview: String
    let tagline: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let runtimeMinutes: Int?
    let rating: Double
    let voteCount: Int
    let certification: String?
    let genres: [String]
    let cast: [CastMember]
    let videos: [RelatedVideo]
    let studios: [String]
    let budget: Int?
    let revenue: Int?
    let mediaInfo: MediaInfo?

    init(json: JSONObject, kind: MediaKind, region: String = "FR") {
        id = json.int("id")
        self.kind = kind
        title = json.string("title") ?? json.string("name") ?? "Untitled"
        originalTitle = json.string("originalTitle") ?? json.string("originalName")
        overview = json.string("overview") ?? ""
        tagline = json.string("tagline")
        posterPath = json.string("posterPath")
        backdropPath = json.string("backdropPath")
        releaseDate = JSON.date(json.string("releaseDate") ?? json.string("firstAirDate"))
        runtimeMinutes = json.optionalInt("runtime")
            ?? json.array("episodeRunTime").compactMap(JSON.int).first
        rating = json.double("voteAverage")
        voteCount = json.int("voteCount")
        genres = json.objects("genres").compactMap { $0.string("name") }
        studios = json.objects("productionCompanies").compactMap { $0.string("name") }
        cast = (json.object("credits")?.objects("cast") ?? json.objects("cast"))
            .prefix(30)
            .map(CastMember.init)
        videos = json.objects("relatedVideos").map(RelatedVideo.init)
        budget = json.optionalInt("budget")
        revenue = json.optionalInt("revenue")
        mediaInfo = MediaInfo(json: json.object("mediaInfo"))

        let certifications = json.object("certifications")
        certification = certifications?.string(region)
            ?? certifications?.string("US")
            ?? certifications?.values.compactMap { $0 as? String }.first
    }

    var posterURL: URL? {
        TMDB.image(path: posterPath, size: "w500")
    }

    var backdropURL: URL? {
        TMDB.image(path: backdropPath, size: "original")
    }
}

struct PersonDetails: Identifiable, Sendable {
    let id: Int
    let name: String
    let biography: String
    let department: String
    let birthday: Date?
    let deathday: Date?
    let placeOfBirth: String?
    let profilePath: String?
    let credits: [MediaItem]

    init(details: JSONObject, credits: JSONObject) {
        id = details.int("id")
        name = details.string("name") ?? ""
        biography = details.string("biography") ?? ""
        department = details.string("knownForDepartment") ?? ""
        birthday = JSON.date(details.string("birthday"))
        deathday = JSON.date(details.string("deathday"))
        placeOfBirth = details.string("placeOfBirth")
        profilePath = details.string("profilePath")
        self.credits = credits.objects("cast")
            .filter { MediaKind($0["mediaType"]) != .person }
            .map(MediaItem.init)
    }

    var imageURL: URL? {
        TMDB.image(path: profilePath, size: "h632")
    }
}

struct RequestItem: Identifiable, Sendable {
    let id: Int
    let status: RequestStatus
    let createdAt: Date?
    let media: MediaItem
    let requestedByID: Int?

    init(json: JSONObject) {
        id = json.int("id")
        status = RequestStatus(rawValue: json.int("status")) ?? .unknown
        createdAt = JSON.dateTime(json.string("createdAt"))
        media = MediaItem(json: json.object("media") ?? [:])
        requestedByID = json.object("requestedBy")?.optionalInt("id")
    }
}

struct MediaServerUser: Sendable {
    let id: String
    let name: String
}

struct MediaServerSession: Sendable {
    let token: String
    let user: MediaServerUser

    init(json: JSONObject) throws {
        token = json.string("AccessToken") ?? ""
        let userJSON = json.object("User") ?? [:]
        user = MediaServerUser(
            id: userJSON.string("Id") ?? "",
            name: userJSON.string("Name") ?? "Media server"
        )
        guard !token.isEmpty, !user.id.isEmpty else {
            throw AppError.invalidResponse("Media server authentication is incomplete.")
        }
    }
}

struct MediaServerUserData: Hashable, Sendable {
    let playbackPositionTicks: Int64
    let played: Bool
    let lastPlayedDate: Date?

    init(json: JSONObject?) {
        playbackPositionTicks = json?.int64("PlaybackPositionTicks") ?? 0
        played = json?.bool("Played") ?? false
        lastPlayedDate = JSON.dateTime(json?.string("LastPlayedDate"))
    }

    init(playbackPositionTicks: Int64, played: Bool, lastPlayedDate: Date?) {
        self.playbackPositionTicks = playbackPositionTicks
        self.played = played
        self.lastPlayedDate = lastPlayedDate
    }
}

struct MediaServerItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let type: String
    let overview: String
    let runtimeTicks: Int64?
    let productionYear: Int?
    let officialRating: String?
    let seriesName: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let providerIDs: [String: String]
    let primaryImageTag: String?
    let backdropImageTag: String?
    let primaryImagePath: String?
    let backdropImagePath: String?
    let userData: MediaServerUserData

    init(json: JSONObject) {
        id = json.string("Id") ?? ""
        name = json.string("Name") ?? "Untitled"
        type = json.string("Type") ?? ""
        overview = json.string("Overview") ?? ""
        runtimeTicks = json.optionalInt64("RunTimeTicks")
        productionYear = json.optionalInt("ProductionYear")
        officialRating = json.string("OfficialRating")
        seriesName = json.string("SeriesName")
        seasonNumber = json.optionalInt("ParentIndexNumber")
        episodeNumber = json.optionalInt("IndexNumber")
        providerIDs = json.object("ProviderIds")?.compactMapValues { $0 as? String } ?? [:]
        primaryImageTag = json.object("ImageTags")?.string("Primary")
        backdropImageTag = json.array("BackdropImageTags").compactMap { $0 as? String }.first
        primaryImagePath = json.string("PrimaryImagePath")
        backdropImagePath = json.string("BackdropImagePath")
        userData = MediaServerUserData(json: json.object("UserData"))
    }

    init(
        id: String,
        name: String,
        type: String,
        overview: String,
        runtimeTicks: Int64?,
        productionYear: Int?,
        officialRating: String?,
        seriesName: String?,
        seasonNumber: Int?,
        episodeNumber: Int?,
        providerIDs: [String: String],
        primaryImagePath: String?,
        backdropImagePath: String?,
        userData: MediaServerUserData
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.overview = overview
        self.runtimeTicks = runtimeTicks
        self.productionYear = productionYear
        self.officialRating = officialRating
        self.seriesName = seriesName
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.providerIDs = providerIDs
        primaryImageTag = nil
        backdropImageTag = nil
        self.primaryImagePath = primaryImagePath
        self.backdropImagePath = backdropImagePath
        self.userData = userData
    }

    var displayTitle: String {
        if type == "Episode", let seriesName {
            return "\(seriesName) · S\(seasonNumber ?? 0) E\(episodeNumber ?? 0)"
        }
        return name
    }
}

struct PlaybackSource: Identifiable, Sendable {
    let item: MediaServerItem
    let mediaSourceID: String
    let playSessionID: String
    let url: URL
    let headers: [String: String]
    let startPosition: TimeInterval
    let playMethod: String

    var id: String { playSessionID }
}

enum AppError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse(String)
    case server(status: Int, message: String)
    case notAuthenticated
    case noPlayableMedia

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The server address is invalid."
        case let .invalidResponse(message): message
        case let .server(status, message): "\(message) (\(status))"
        case .notAuthenticated: "The session has expired. Reconnect this profile."
        case .noPlayableMedia: "No playable media was found on the media server."
        }
    }
}

typealias JSONObject = [String: Any]

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? {
        let value = self[key]
        if let value = value as? String, !value.isEmpty { return value }
        return nil
    }

    func int(_ key: String) -> Int {
        JSON.int(self[key]) ?? 0
    }

    func optionalInt(_ key: String) -> Int? {
        JSON.int(self[key])
    }

    func int64(_ key: String) -> Int64 {
        JSON.int64(self[key]) ?? 0
    }

    func optionalInt64(_ key: String) -> Int64? {
        JSON.int64(self[key])
    }

    func double(_ key: String) -> Double {
        JSON.double(self[key]) ?? 0
    }

    func bool(_ key: String) -> Bool {
        JSON.bool(self[key]) ?? false
    }

    func object(_ key: String) -> JSONObject? {
        self[key] as? JSONObject
    }

    func array(_ key: String) -> [Any] {
        self[key] as? [Any] ?? []
    }

    func objects(_ key: String) -> [JSONObject] {
        array(key).compactMap { $0 as? JSONObject }
    }
}

enum JSON {
    static func object(from data: Data) throws -> JSONObject {
        guard let object = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
            throw AppError.invalidResponse("The server returned invalid JSON.")
        }
        return object
    }

    static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? String { return Int64(value) }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    static func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }

    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        return DateFormatter.isoDay.date(from: value)
    }

    static func dateTime(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

enum TMDB {
    static func image(path: String?, size: String) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }
}

extension DateFormatter {
    static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
