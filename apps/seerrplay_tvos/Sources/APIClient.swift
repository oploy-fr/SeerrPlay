import Foundation

struct APIResponse: @unchecked Sendable {
    let data: Data
    let response: HTTPURLResponse

    var json: JSONObject {
        get throws { try JSON.object(from: data) }
    }
}

final class APIClient: @unchecked Sendable {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    func request(
        baseURL: URL,
        path: String,
        method: String = "GET",
        query: [String: String?] = [:],
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> APIResponse {
        let cleanPath = path.split(separator: "/").map(String.init)
        var url = baseURL
        for component in cleanPath {
            url.appendPathComponent(component)
        }
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = query.compactMap { key, value in
                value.map { URLQueryItem(name: key, value: $0) }
            }
            guard let queryURL = components?.url else { throw AppError.invalidURL }
            url = queryURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.invalidResponse("The server returned no HTTP response.")
        }
        guard 200 ..< 300 ~= http.statusCode else {
            let message = (try? JSON.object(from: data).string("message"))
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AppError.server(status: http.statusCode, message: message)
        }
        return APIResponse(data: data, response: http)
    }
}
