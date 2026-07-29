import Foundation

protocol MediaServerService: Sendable {
    func currentSession() async throws -> MediaServerSession
    func resume(limit: Int) async throws -> [MediaServerItem]
    func nextUp(limit: Int) async throws -> [MediaServerItem]
    func library(search: String, limit: Int) async throws -> [MediaServerItem]
    func details(id: String) async throws -> MediaServerItem
    func resolve(media: MediaItem) async throws -> MediaServerItem
    func imageURL(for item: MediaServerItem, backdrop: Bool) async -> URL?
    func playback(for requestedItem: MediaServerItem) async throws -> PlaybackSource
    func report(
        event: String,
        source: PlaybackSource,
        position: TimeInterval,
        paused: Bool
    ) async
}
