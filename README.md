# VSPlayer

VSPlayer is the media player used by the **TRASSIR Mobile** iOS app. It is a fork of
[KSPlayer](https://github.com/kingslay/KSPlayer) (an FFmpeg-based player built on top of
[FFmpegKit](https://github.com/kingslay/FFmpegKit)) and is distributed as a Swift Package.

## Why a fork

The fork carries project-specific fixes for cloud video surveillance playback that are not
present upstream. The first one:

### Video-only fallback for malformed audio in HLS archive

Some cameras deliver an HLS archive segment whose audio track is broken
(`aac, 0 channels, unspecified sample rate`). In stock KSPlayer such a track is still enabled:
it never decodes (its decoded-frame count stays at `0`), and because the audio clock is the
master clock, the video clock waits for it forever and playback hangs in `buffering` — on both
real devices and the simulator.

VSPlayer skips audio tracks with an invalid descriptor (zero channels or unspecified sample
rate) in `MEPlayerItem.createCodec`. The track is left disabled, `isAudioStalled` stays `true`,
the video clock becomes the master clock, and the video plays without audio (video-only
fallback). Streams with valid audio are unaffected.

## Installation (Swift Package Manager)

In Xcode: **File -> Add Package Dependencies...**, enter the repository URL:

```
https://github.com/VolkovsaVSA/VSPlayer
```

Choose the dependency rule **Up to Next Minor** from `0.1.0`, then add the **VSPlayer** library
product to your app target.

`Package.swift`:

```swift
.package(url: "https://github.com/VolkovsaVSA/VSPlayer", .upToNextMinor(from: "0.1.0"))
```

Then:

```swift
import VSPlayer
```

The FFmpeg backend is a fork — [`VolkovsaVSA/FFmpegKit`](https://github.com/VolkovsaVSA/FFmpegKit)
pinned to the exact version `6.1.3` — and is resolved automatically as a transitive Swift Package
dependency. The fork only sanitizes an invalid `CFBundleIdentifier` in the prebuilt
`libshaderc_combined` framework (`_` -> `-`) so Xcode / App Store validation passes; the FFmpeg
binaries are unchanged from upstream `6.1.3`.

## Versioning

Semantic Versioning. Releases are tagged on `main` (for example `0.1.0`) and published as GitHub
Releases.

- `main` — stable, released, tagged.
- `develop` — integration branch for development.
- feature/release branches (for example `v0_1`) branch off `develop`.

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

Distributed under the Apache License 2.0 (see [LICENSE](LICENSE)). VSPlayer is a derivative work
of KSPlayer; the original project's authorship and license terms are preserved.
