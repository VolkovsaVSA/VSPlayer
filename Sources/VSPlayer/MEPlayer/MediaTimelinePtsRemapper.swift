//
//  MediaTimelinePtsRemapper.swift
//  VSPlayer
//
//  Created by Sergei Volkov on 2026/8/11.
//

import Foundation
import Libavcodec

/// Rewrites video timestamps of a server-paced HLS stream onto a continuous media timeline.
///
/// Such a playlist is generated per playback request: every segment opens its own timestamp
/// range, so demuxer PTS/DTS jump at segment boundaries and cannot drive the playback clock.
///
/// - Time-compressed timestamps: when the server scales playback speed it packs several frames
///   into one frame slot, and those deltas are preserved — the compression is exactly what makes
///   the picture run faster. Forcing 1/fps would stretch the same frames back to 1x.
/// - Sparse timestamps: a gap wider than a couple of frame slots is a segment discontinuity and
///   collapses to ~1/fps, keeping the media timeline continuous.
///
/// Packets are never dropped here: discarding H.264 P-frames without their I-frame produces
/// artifacts. The visible speed comes from the stream itself.
final class MediaTimelinePtsRemapper: @unchecked Sendable {
    /// Deltas wider than this many frame slots are treated as segment discontinuities.
    private static let maxPreservedDeltaFrames: Int64 = 2

    private let lock = NSLock()
    private var nextPts: Int64 = 0
    private var lastOriginalDts: Int64?
    private var cachedFrameDuration: Int64 = 0
    private var cachedTimebaseDen: Int32 = 0
    private var cachedTimebaseNum: Int32 = 0
    private var cachedFps: Float = 0

    func reset() {
        lock.lock()
        nextPts = 0
        lastOriginalDts = nil
        cachedFrameDuration = 0
        cachedTimebaseDen = 0
        cachedTimebaseNum = 0
        cachedFps = 0
        lock.unlock()
    }

    func remapPacket(_ packet: Packet) {
        guard packet.assetTrack.mediaType == .video,
              let corePacket = packet.corePacket
        else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        let oneFrame = frameDurationTicksLocked(
            timebase: packet.assetTrack.timebase,
            fps: packet.assetTrack.nominalFrameRate
        )
        // `packet.timestamp` is filled from demuxer PTS/DTS in `assetTrack.didSet`
        // before remap runs (see MEPlayerItem.reading).
        let originalDts = packet.timestamp
        let duration = durationTicksLocked(originalDts: originalDts, oneFrame: oneFrame)
        corePacket.pointee.pts = nextPts
        corePacket.pointee.dts = nextPts
        corePacket.pointee.duration = duration
        packet.timestamp = nextPts
        packet.duration = duration
        nextPts += duration
        lastOriginalDts = originalDts
    }

    /// Prefer the remapped packet timeline for decoded frames: `best_effort_timestamp` may
    /// restore the original segment timestamps.
    func timestampForDecodedFrame(packet: Packet, fallbackDuration: Int64) -> (timestamp: Int64, duration: Int64) {
        let duration: Int64
        if packet.duration > 0 {
            duration = packet.duration
        } else if fallbackDuration > 0 {
            duration = fallbackDuration
        } else {
            lock.lock()
            duration = frameDurationTicksLocked(
                timebase: packet.assetTrack.timebase,
                fps: packet.assetTrack.nominalFrameRate
            )
            lock.unlock()
        }
        return (packet.timestamp, duration)
    }

    private func durationTicksLocked(originalDts: Int64, oneFrame: Int64) -> Int64 {
        guard let lastOriginalDts, originalDts > lastOriginalDts else {
            return oneFrame
        }
        let delta = originalDts - lastOriginalDts
        let maxPreserved = oneFrame * Self.maxPreservedDeltaFrames
        if delta <= maxPreserved {
            return max(1, delta)
        }
        return oneFrame
    }

    private func frameDurationTicksLocked(timebase: Timebase, fps: Float) -> Int64 {
        let safeFps = max(fps, 1)
        if cachedFrameDuration > 0,
           cachedTimebaseDen == timebase.den,
           cachedTimebaseNum == timebase.num,
           abs(cachedFps - safeFps) < 0.01
        {
            return cachedFrameDuration
        }
        let secondsPerFrame = 1 / Double(safeFps)
        let ticks = Int64((secondsPerFrame * Double(timebase.den) / Double(max(timebase.num, 1))).rounded())
        cachedFrameDuration = max(1, ticks)
        cachedTimebaseDen = timebase.den
        cachedTimebaseNum = timebase.num
        cachedFps = safeFps
        return cachedFrameDuration
    }
}
