# VSPlayer

VSPlayer is a media playback library for Apple platforms, distributed as a Swift Package.
It is a fork of [KSPlayer](https://github.com/kingslay/KSPlayer) built on
[FFmpegKit](https://github.com/kingslay/FFmpegKit) (FFmpeg 6.x).

The library targets apps that need broad format and protocol support beyond what
`AVPlayer` offers, while still integrating with UIKit / SwiftUI and system features such as
Picture in Picture and Now Playing controls.

## Supported platforms

| Platform        | Minimum version |
|-----------------|-----------------|
| iOS             | 13.0            |
| tvOS            | 13.0            |
| macOS           | 10.15           |
| Mac Catalyst    | 14.0            |
| visionOS        | 1.0             |

## Features

### Playback backends

VSPlayer can open a URL with two backends, configured through `VSOptions`:

- **VSAVPlayer** — wraps system `AVPlayer` / `AVURLAsset`. Preferred for HLS and other
  formats natively supported by Apple frameworks.
- **VSMEPlayer** — FFmpeg-based demuxer and decoder (`MEPlayerItem`). Used as a fallback
  or when explicitly selected. Supports codecs and containers that `AVPlayer` cannot handle
  (for example H.265 in some setups, RTSP, FLV, MKV, and custom HTTP streams).

By default the player tries the first backend and falls back to the second on failure
(`firstPlayerType` / `secondPlayerType` on `VSOptions`).

### Protocols and inputs

Through the FFmpeg backend, common network and file protocols are supported, including HTTP(S),
HLS, RTSP, RTMP, UDP, and file URLs. Protocol availability depends on the linked FFmpeg build;
see `formatContextOptions` (for example `protocol_whitelist`) to restrict or extend the set.

### Video

- Software decoding via FFmpeg and hardware decoding via VideoToolbox (configurable with
  `VSOptions.hardwareDecode`).
- Metal-based video output (`MetalPlayView`) with optional rotation and deinterlacing filters.
- Adaptive bitrate hinting for multi-rendition sources.
- Thumbnail generation and seek preview support.

### Audio

- Output through `AudioEnginePlayer` (default) or alternative audio renderers.
- Resampling and channel-layout normalization.
- Automatic fallback to **video-only playback** when an declared audio track cannot be decoded
  (invalid or incomplete codec parameters), so video is not blocked by a broken audio clock.

### Subtitles

- Embedded subtitle tracks (FFmpeg path).
- External subtitle files and search providers (OpenSubtitles and similar integrations in the
  subtitle module).

### UI integration

- **`VSPlayerLayer`** — `CALayer` subclass that owns playback state, buffering, and delegate
  callbacks; suitable for UIKit.
- **`VSVideoPlayerView` / `IOSVideoPlayerView`** — ready-made player views with controls
  (play/pause, seek bar, fullscreen, PiP button, subtitle and track selection on supported
  platforms).
- **SwiftUI** — `VSVideoPlayerView` and builder APIs for Compose-style integration.
- **Picture in Picture** — `VSPictureInPictureController` on iOS / tvOS where supported.

### Configuration (`VSOptions`)

`VSOptions` centralizes playback behaviour:

| Area | Examples |
|------|----------|
| Buffering | `preferredForwardBufferDuration`, `maxBufferDuration`, `isSecondOpen` |
| Seek | `isAccurateSeek`, `isSeekedAutoPlay`, `seekFlags` |
| FFmpeg probe | `probesize`, `maxAnalyzeDuration`, `formatContextOptions`, `userAgent` |
| Decode | `hardwareDecode`, `syncDecodeAudio`, `syncDecodeVideo`, `videoDisable` |
| Filters | `videoFilters`, `audioFilters`, `autoDeInterlace`, `autoRotate` |
| Lifecycle | `isAutoPlay`, `isLoopPlay`, `canBackgroundPlay` |

Static helpers on `VSOptions` configure the default player stack before creating a layer or view.

## Installation (Swift Package Manager)

Repository URL:

```
https://github.com/VolkovsaVSA/VSPlayer
```

Library product to add to your app target: **VSPlayer**.

The package pulls in
[`VolkovsaVSA/FFmpegKit`](https://github.com/VolkovsaVSA/FFmpegKit) at exactly **6.1.3**
as a transitive dependency. That fork only fixes an invalid `CFBundleIdentifier` in the
prebuilt `libshaderc_combined` framework; FFmpeg binaries match upstream 6.1.3.

### Xcode

1. **File → Add Package Dependencies…**
2. Paste the repository URL above.
3. Choose a dependency rule (see below).
4. Add the **VSPlayer** product to your application target.

### `Package.swift` dependency rules

Pin to an **exact version** when you need reproducible builds and controlled upgrades:

```swift
dependencies: [
    .package(url: "https://github.com/VolkovsaVSA/VSPlayer", exact: "0.1.1"),
]
```

Allow **patch and minor** updates within the same major line (`0.1.1` … `< 0.2.0`):

```swift
dependencies: [
    .package(url: "https://github.com/VolkovsaVSA/VSPlayer", .upToNextMinor(from: "0.1.1")),
]
```

Allow **minor and major** updates within the next major line (`0.1.1` … `< 1.0.0`):

```swift
dependencies: [
    .package(url: "https://github.com/VolkovsaVSA/VSPlayer", .upToNextMajor(from: "0.1.1")),
]
```

Target dependency:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "VSPlayer", package: "VSPlayer"),
    ]
)
```

### Import

```swift
import VSPlayer
```

### Minimal usage

```swift
import VSPlayer

let options = VSOptions()
options.isAutoPlay = true

let player = VSPlayerLayer(url: videoURL, options: options)
player.frame = view.bounds
view.layer.addSublayer(player)
player.play()
```

For SwiftUI, use `VSVideoPlayerView(url:options:)` or the builder APIs in
`Sources/VSPlayer/SwiftUI/`.

After changing the package version in Xcode, use **File → Packages → Reset Package Caches**
if SwiftPM resolves an stale revision.

## Versioning and branches

Releases follow [Semantic Versioning](https://semver.org/). Tags (for example `0.1.1`) are
published on GitHub Releases.

| Branch | Purpose |
|--------|---------|
| `main` | Stable; tagged releases |
| `develop` | Integration branch |
| `v0_1_1`, `v0_2`, … | Release and feature branches cut from `develop` |

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

Distributed under the Apache License 2.0 (see [LICENSE](LICENSE)). VSPlayer is a derivative work
of KSPlayer; the original project's authorship and license terms are preserved.
