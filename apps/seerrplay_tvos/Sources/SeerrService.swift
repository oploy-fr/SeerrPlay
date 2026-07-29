import Foundation

actor SeerrService {
    private let client: APIClient
    private let apiURL: URL
    private var sessionCookie: String

    init(baseURL: URL, sessionCookie: String = "", client: APIClient = APIClient()) {
        self.client = client
        self.sessionCookie = sessionCookie
        if baseURL.path.hasSuffix("/api/v1") {
            apiURL = baseURL
        } else {
            apiURL = baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("v1")
        }
    }

    func restore(cookie: String) {
        sessionCookie = cookie
    }

    func currentCookie() -> String {
        sessionCookie
    }

    func publicConfiguration() async throws -> SeerrPublicConfiguration {
        let response = try await client.request(
            baseURL: apiURL,
            path: "settings/public"
        )
        return try SeerrPublicConfiguration(json: response.json)
    }

    func login(
        mode: SeerrLoginMode,
        username: String,
        password: String,
        mediaServerType: MediaServerType,
        plexToken: String? = nil
    ) async throws -> SeerrUser {
        let path: String
        let values: JSONObject
        if mode == .local {
            path = "auth/local"
            values = [
                "email": username.trimmingCharacters(in: .whitespacesAndNewlines),
                "password": password,
            ]
        } else if mediaServerType == .plex {
            guard let plexToken, !plexToken.isEmpty else {
                throw AppError.notAuthenticated
            }
            path = "auth/plex"
            values = ["authToken": plexToken]
        } else {
            path = "auth/jellyfin"
            values = [
                "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
                "password": password,
                "serverType": mediaServerType.rawValue,
            ]
        }
        let body = try JSONSerialization.data(withJSONObject: values)
        let response = try await client.request(
            baseURL: apiURL,
            path: path,
            method: "POST",
            body: body
        )
        captureCookie(from: response.response)
        guard !sessionCookie.isEmpty else {
            throw AppError.invalidResponse("Seerr did not return a valid session.")
        }
        return SeerrUser(json: try response.json)
    }

    func me() async throws -> SeerrUser {
        let response = try await authenticated(path: "auth/me")
        return SeerrUser(json: try response.json)
    }

    func trending(page: Int = 1, language: String) async throws -> [MediaItem] {
        let response = try await authenticated(
            path: "discover/trending",
            query: [
                "page": String(page),
                "language": language,
                "timeWindow": "day",
            ]
        )
        return try response.json.objects("results").map(MediaItem.init)
    }

    func discover(kind: MediaKind, page: Int = 1, language: String) async throws -> [MediaItem] {
        let path = kind == .tv ? "discover/tv" : "discover/movies"
        let response = try await authenticated(
            path: path,
            query: ["page": String(page), "language": language]
        )
        return try response.json.objects("results").map(MediaItem.init)
    }

    func search(query: String, page: Int = 1, language: String) async throws -> [MediaItem] {
        let response = try await authenticated(
            path: "search",
            query: [
                "query": query.trimmingCharacters(in: .whitespacesAndNewlines),
                "page": String(page),
                "language": language,
            ]
        )
        return try response.json.objects("results")
            .map(MediaItem.init)
            .filter { $0.kind != .person }
    }

    func details(for item: MediaItem, language: String, region: String) async throws -> MediaDetails {
        let path = item.kind == .tv ? "tv/\(item.id)" : "movie/\(item.id)"
        let response = try await authenticated(path: path, query: ["language": language])
        return MediaDetails(json: try response.json, kind: item.kind, region: region)
    }

    func person(id: Int, language: String) async throws -> PersonDetails {
        async let detailsResponse = authenticated(
            path: "person/\(id)",
            query: ["language": language]
        )
        async let creditsResponse = authenticated(
            path: "person/\(id)/combined_credits",
            query: ["language": language]
        )
        return try await PersonDetails(
            details: detailsResponse.json,
            credits: creditsResponse.json
        )
    }

    func requests(userID: Int, take: Int = 100) async throws -> [RequestItem] {
        let response = try await authenticated(
            path: "user/\(userID)/requests",
            query: ["take": String(take), "skip": "0"]
        )
        return try response.json.objects("results").map(RequestItem.init)
    }

    func createRequest(for item: MediaItem) async throws {
        var body: JSONObject = [
            "mediaType": item.kind.rawValue,
            "mediaId": item.id,
        ]
        if item.kind == .tv {
            body["seasons"] = "all"
        }
        _ = try await authenticated(path: "request", method: "POST", body: body)
    }

    func deleteRequest(id: Int) async throws {
        _ = try await authenticated(path: "request/\(id)", method: "DELETE")
    }

    private func authenticated(
        path: String,
        method: String = "GET",
        query: [String: String?] = [:],
        body: JSONObject? = nil
    ) async throws -> APIResponse {
        guard !sessionCookie.isEmpty else { throw AppError.notAuthenticated }
        let bodyData = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        return try await client.request(
            baseURL: apiURL,
            path: path,
            method: method,
            query: query,
            body: bodyData,
            headers: ["Cookie": sessionCookie]
        )
    }

    private func captureCookie(from response: HTTPURLResponse) {
        let fields = response.allHeaderFields
        let rawCookie = fields.first { key, _ in
            String(describing: key).caseInsensitiveCompare("Set-Cookie") == .orderedSame
        }.map { String(describing: $0.value) } ?? ""
        guard let range = rawCookie.range(
            of: #"connect\.sid=[^;,\s]+"#,
            options: .regularExpression
        ) else {
            return
        }
        sessionCookie = String(rawCookie[range])
    }
}
