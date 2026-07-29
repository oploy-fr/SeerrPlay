import AVKit
import SwiftUI

struct NativePlayerView: UIViewControllerRepresentable {
    @EnvironmentObject private var app: AppModel
    let source: PlaybackSource

    func makeCoordinator() -> Coordinator {
        Coordinator(app: app, source: source)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let options = ["AVURLAssetHTTPHeaderFieldsKey": source.headers]
        let asset = AVURLAsset(url: source.url, options: options)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true

        context.coordinator.attach(to: player)
        if source.startPosition > 2 {
            player.seek(
                to: CMTime(seconds: source.startPosition, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { _ in player.play() }
        } else {
            player.play()
        }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(
        _ controller: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        coordinator.stop()
        controller.player?.pause()
        controller.player = nil
    }

    final class Coordinator: @unchecked Sendable {
        private let app: AppModel
        private let source: PlaybackSource
        private weak var player: AVPlayer?
        private var timeObserver: Any?
        private var statusObservation: NSKeyValueObservation?

        init(app: AppModel, source: PlaybackSource) {
            self.app = app
            self.source = source
        }

        func attach(to player: AVPlayer) {
            self.player = player
            Task { @MainActor in
                await app.reportPlayback(
                    event: "Playing",
                    source: source,
                    position: source.startPosition,
                    paused: false
                )
            }
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 10, preferredTimescale: 600),
                queue: .main
            ) { [weak self] time in
                guard let self else { return }
                Task { @MainActor in
                    await self.app.reportPlayback(
                        event: "Playing/Progress",
                        source: self.source,
                        position: time.seconds.isFinite ? time.seconds : 0,
                        paused: self.player?.timeControlStatus != .playing
                    )
                }
            }
            statusObservation = player.observe(\.timeControlStatus, options: [.new]) {
                [weak self] player, _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.app.reportPlayback(
                        event: "Playing/Progress",
                        source: self.source,
                        position: player.currentTime().seconds.isFinite
                            ? player.currentTime().seconds
                            : 0,
                        paused: player.timeControlStatus != .playing
                    )
                }
            }
        }

        func stop() {
            guard let player else { return }
            let position = player.currentTime().seconds
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            statusObservation = nil
            Task { @MainActor in
                await app.reportPlayback(
                    event: "Playing/Stopped",
                    source: source,
                    position: position.isFinite ? position : 0,
                    paused: true
                )
            }
        }
    }
}
