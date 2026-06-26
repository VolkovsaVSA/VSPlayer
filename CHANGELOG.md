# Changelog

All notable changes to VSPlayer are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2026-06-26

### Fixed
- `LoadingState` exposes a public initializer so host apps can adjust playable state
  (e.g. archive HLS video-only fallback in `TrassirVSOptions`).

## [0.1.4] - 2026-06-26

### Fixed
- When `audioDisable` is set, audio streams are not probed into `FFmpegAssetTrack` (avoids
  `AudioFormatDescription err=-12710` and spurious `Resample` setup on corrupt AAC).
- `mainClock()` always uses the video clock when `audioDisable` is true.
- Audio route-change handling is skipped when `audioDisable` is true.

## [0.1.3] - 2026-06-26

### Added
- `VSOptions.audioDisable` — skip opening/decoding audio entirely (video-only playback).
- Runtime fallback: disable audio when packets arrive but no decodable frames are produced
  while video is already decoding.

### Fixed
- `sourceDidOpened` skips `AudioEnginePlayer.prepare()` when the audio track has no
  renderable `CMFormatDescription` (e.g. `AudioFormatDescription err=-12710`).

## [0.1.2] - 2026-06-26

### Fixed
- `AudioDescriptor.isDecodable` now checks raw FFmpeg codec parameters instead of
  playback defaults (stereo layout / 48 kHz) that masked broken AAC tracks.
- `sourceDidOpened` re-validates the enabled audio track against live `codecpar`
  before calling `AudioEnginePlayer.prepare()`.

## [0.1.1] - 2026-06-26

### Fixed
- Playback no longer stalls when a stream declares an audio track that cannot be decoded
  (incomplete codec parameters after probe, e.g. zero channels or unspecified sample format).
- Stricter audio-track validation when opening a media source.
- Runtime fallback to video-only playback when an enabled audio track turns out to be
  undecodable after the source is opened.

## [0.1.0] - 2026-06-25

First release of VSPlayer — a fork of [KSPlayer](https://github.com/kingslay/KSPlayer)
distributed as a Swift Package.

### Added
- Swift Package Manager distribution of the `VSPlayer` library product.
- Video-only fallback for streams with a malformed audio track: tracks whose descriptor is
  invalid at open time (zero channels or unspecified sample rate) are not enabled, so the
  video clock drives playback instead of waiting forever on an empty audio buffer.

### Changed
- Renamed all `KS*` symbols to `VS*` across the package (module, types and options).
- FFmpeg backend switched to the fork
  [`VolkovsaVSA/FFmpegKit`](https://github.com/VolkovsaVSA/FFmpegKit) pinned to the exact
  version `6.1.3` (resolved transitively).

### Fixed
- Invalid `CFBundleIdentifier` in the prebuilt `libshaderc_combined` framework
  (`com.kintan.ksplayer.libshaderc_combined` -> `...libshaderc-combined`), which made Xcode /
  App Store validation fail when the framework was embedded via SPM. Fixed at the source in the
  forked FFmpegKit; the FFmpeg binaries are otherwise unchanged from upstream `6.1.3`.

[0.1.2]: https://github.com/VolkovsaVSA/VSPlayer/releases/tag/0.1.2
[0.1.1]: https://github.com/VolkovsaVSA/VSPlayer/releases/tag/0.1.1
[0.1.0]: https://github.com/VolkovsaVSA/VSPlayer/releases/tag/0.1.0
