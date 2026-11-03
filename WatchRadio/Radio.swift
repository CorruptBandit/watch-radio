import AVFoundation
import MediaPlayer

/// Plays one internet radio stream. Everything here is event-driven: no timers,
/// no periodic time observers, no metadata polling, so the CPU can sleep.
@MainActor
final class Radio: ObservableObject {
    enum State: Equatable {
        case stopped, connecting, playing, failed
    }

    @Published private(set) var state: State = .stopped {
        didSet { publishNowPlaying() }
    }

    private let player = AVPlayer()
    private var controlObserver: NSKeyValueObservation?
    private var itemObserver: NSKeyValueObservation?
    private var url: URL?
    private var title = ""

    init() {
        controlObserver = player.observe(\.timeControlStatus) { [weak self] player, _ in
            MainActor.assumeIsolated {
                guard let self, player.currentItem != nil, self.state != .failed else { return }
                switch player.timeControlStatus {
                case .playing: self.state = .playing
                case .waitingToPlayAtSpecifiedRate: self.state = .connecting
                case .paused: self.state = .stopped
                @unknown default: break
                }
            }
        }

        // Headphone/lock-screen controls
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.state == .stopped || self.state == .failed ? self.resume() : self.stop()
            }
            return .success
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                if raw == AVAudioSession.InterruptionType.began.rawValue { self?.stop() }
            }
        }
    }

    func play(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host != nil
        else {
            state = .failed
            return
        }
        self.url = url
        title = url.host ?? "Radio"
        start(url)
    }

    private func resume() {
        if let url { start(url) }
    }

    private func start(_ url: URL) {
        teardown()
        state = .connecting
        Task { [weak self] in
            guard let self else { return }
            do {
                let session = AVAudioSession.sharedInstance()
                // longFormAudio is what lets watchOS keep streaming in the background.
                try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
                try await session.activate()
            } catch {
                state = .failed
                return
            }
            // Stopped (or restarted) while the session was activating.
            guard state == .connecting else { return }

            let item = AVPlayerItem(url: url)
            itemObserver = item.observe(\.status) { [weak self] item, _ in
                MainActor.assumeIsolated {
                    if item.status == .failed { self?.fail() }
                }
            }
            player.replaceCurrentItem(with: item)
            player.play()
        }
    }

    func stop() {
        teardown()
        state = .stopped
    }

    private func fail() {
        teardown()
        state = .failed
    }

    /// Drop the item so the network connection closes, and release the audio session.
    private func teardown() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemObserver = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func publishNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0,
        ]
    }
}
