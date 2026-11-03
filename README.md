# Watch Radio

A minimal, standalone Apple Watch app that plays an internet radio stream. You supply the URL; the code contains no stations. It keeps playing in the background and does as little work as possible.

- watchOS 11+, standalone (no iPhone app needed)
- Plays direct MP3/AAC streams (Icecast/Shoutcast) and HLS
- Background audio, Now Playing and headphone play/pause controls
- Double Tap (Series 9+/Ultra 2) toggles play/stop

## Setup

Open `WatchRadio.xcodeproj`, pick your team and set a bundle ID under Signing & Capabilities. The stream URL is not in the repo or the build: enter it in the app's text field (Scribble, dictation, or the paired iPhone's keyboard); it is saved on the Watch between launches.

## Install on your Watch

```bash
./deploy.sh
```

Needs a paired Watch with Developer Mode on. Override device detection with `WATCH_DEVICE_ID=<udid>`. A free Apple ID's profile expires after 7 days, so re-run to refresh.

## Audio notes

- Uses `AVAudioSession` `.playback` with the `.longFormAudio` policy, which is what allows background streaming on watchOS. It normally routes to Bluetooth headphones and may show the route picker on first play.
- Plain `http://` streams are allowed (`NSAllowsArbitraryLoadsForMedia`); all other loads stay under App Transport Security.

## Battery

No timers, no periodic observers, no metadata polling, no animations. State changes come from KVO events only. Stopping tears down the player item (closing the connection) and deactivates the audio session.

## License

MIT
