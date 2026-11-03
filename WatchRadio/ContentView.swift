import SwiftUI

struct ContentView: View {
    @StateObject private var radio = Radio()
    @AppStorage("streamURL") private var streamURL = ""

    private var isActive: Bool { radio.state == .connecting || radio.state == .playing }

    var body: some View {
        VStack(spacing: 8) {
            Button {
                if isActive { radio.stop() } else { radio.play(streamURL) }
            } label: {
                Image(systemName: isActive ? "stop.fill" : "play.fill")
                    .font(.title)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .handGestureShortcut(.primaryAction)

            // Plain text only: no spinners or animation while buffering.
            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Stream URL", text: $streamURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal)
    }

    private var status: String {
        switch radio.state {
        case .stopped: streamURL.isEmpty ? "Enter a stream URL" : "Stopped"
        case .connecting: "Connecting…"
        case .playing: "Playing"
        case .failed: "Can't play this URL"
        }
    }
}
