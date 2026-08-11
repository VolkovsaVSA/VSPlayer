//
//  MediaTimelinePacer.swift
//  VSPlayer
//
//  Created by Sergei Volkov on 2026/8/11.
//

import Foundation

/// Decides, for a server-paced HLS stream, whether the frame at the head of the render queue is
/// due, still ahead, or already behind.
///
/// The player's main clock is re-anchored to the PTS of every displayed frame
/// (`MEPlayerItem.setVideo`), so the leftover fraction of a frame interval is discarded on
/// every display-link tick and the renderer advances `ceil(tick / spacing)` frames per tick.
/// Whenever the media frame rate is not a multiple of the display-link rate that rounding makes
/// media time — and therefore the visible speed — run fast: 20fps media on a 30Hz link or 80fps
/// media on a 60Hz link both drift to exactly 1.5x.
///
/// Anchoring the target media time to wall time instead removes the rounding: frames are held or
/// discarded so that media time advances 1.0 second per wall second, which is what the server
/// already encoded the requested speed into.
struct MediaTimelinePacer {
    enum Decision: Equatable {
        /// The frame is ahead of the target; keep the current picture on screen.
        case wait
        /// The frame is due.
        case present
        /// The frame is behind the target; move on to the following one.
        case discard
    }

    /// Jitter allowed before a frame counts as early or late.
    static let tolerance: TimeInterval = 0.002
    /// Drift above this is treated as a discontinuity (seek, pause, long stall) and re-anchored,
    /// instead of flushing the queue or freezing the picture for seconds.
    static let maxDrift: TimeInterval = 1

    private var mediaAnchor: TimeInterval?
    private var wallAnchor: TimeInterval = 0

    mutating func reset() {
        mediaAnchor = nil
        wallAnchor = 0
    }

    /// - Returns: what to do with the frame and its offset from the target media time.
    mutating func decide(frameTime: TimeInterval, now: TimeInterval) -> (Decision, TimeInterval) {
        guard let mediaAnchor else {
            anchor(frameTime: frameTime, now: now)
            return (.present, 0)
        }
        let diff = frameTime - (mediaAnchor + (now - wallAnchor))
        guard abs(diff) <= Self.maxDrift else {
            anchor(frameTime: frameTime, now: now)
            return (.present, 0)
        }
        if diff > Self.tolerance {
            return (.wait, diff)
        }
        if diff < -Self.tolerance {
            return (.discard, diff)
        }
        return (.present, diff)
    }

    private mutating func anchor(frameTime: TimeInterval, now: TimeInterval) {
        mediaAnchor = frameTime
        wallAnchor = now
    }
}
