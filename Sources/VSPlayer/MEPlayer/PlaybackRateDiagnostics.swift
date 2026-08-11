//
//  PlaybackRateDiagnostics.swift
//  VSPlayer
//
//  Created by Sergei Volkov on 2026/8/11.
//

import Foundation

/// Aggregates playback counters of a server-paced HLS stream into one summary per wall second.
///
/// A stream scaled to Nx packs `speedFactor` seconds of source into one media-second, so keeping
/// up with it requires pulling `speedFactor * fps` frames per wall second out of the render
/// queue. When the decoder cannot supply that many, media time advances slower than wall time and
/// playback silently caps below the requested speed. The snapshot exposes both sides of that
/// budget: how many frames were consumed and how far media time actually moved.
struct PlaybackRateDiagnostics {
    struct Snapshot {
        let interval: TimeInterval
        let displayedFrames: Int
        let droppedFrames: Int
        let mediaSecondsAdvanced: TimeInterval
        let speedFactor: Double

        var consumedFrames: Int { displayedFrames + droppedFrames }
        /// Frames pulled from the render queue per wall second — the decode throughput ceiling.
        var consumedFPS: Double { rate(Double(consumedFrames)) }
        var displayedFPS: Double { rate(Double(displayedFrames)) }
        var droppedFPS: Double { rate(Double(droppedFrames)) }
        /// Media seconds per wall second. 1.0 means the player keeps up with the stream.
        var mediaRate: Double { rate(mediaSecondsAdvanced) }
        /// Source seconds per wall second, i.e. the speed the viewer actually sees.
        var effectiveSpeed: Double { mediaRate * speedFactor }

        var logLine: String {
            String(
                format: "[rate-diag] speed=%.1f effective=%.2fx mediaRate=%.2f consumed=%.1ffps displayed=%.1ffps dropped=%.1ffps window=%.2fs",
                speedFactor, effectiveSpeed, mediaRate, consumedFPS, displayedFPS, droppedFPS, interval
            )
        }

        private func rate(_ value: Double) -> Double {
            interval > 0 ? value / interval : 0
        }
    }

    static let windowDuration: TimeInterval = 1

    private var windowStart: TimeInterval?
    private var windowStartMediaTime: TimeInterval?
    private var lastMediaTime: TimeInterval?
    private var displayedFrames = 0
    private var droppedFrames = 0

    mutating func reset() {
        windowStart = nil
        windowStartMediaTime = nil
        lastMediaTime = nil
        displayedFrames = 0
        droppedFrames = 0
    }

    mutating func record(
        displayed: Int,
        dropped: Int,
        mediaTime: TimeInterval?,
        speedFactor: Double,
        now: TimeInterval
    ) -> Snapshot? {
        guard let windowStart else {
            startWindow(at: now, mediaTime: mediaTime)
            accumulate(displayed: displayed, dropped: dropped, mediaTime: mediaTime)
            return nil
        }
        accumulate(displayed: displayed, dropped: dropped, mediaTime: mediaTime)
        let interval = now - windowStart
        guard interval >= Self.windowDuration else {
            return nil
        }
        let snapshot = Snapshot(
            interval: interval,
            displayedFrames: displayedFrames,
            droppedFrames: droppedFrames,
            mediaSecondsAdvanced: advancedMediaSeconds(),
            speedFactor: speedFactor
        )
        startWindow(at: now, mediaTime: lastMediaTime)
        return snapshot
    }

    private mutating func startWindow(at now: TimeInterval, mediaTime: TimeInterval?) {
        windowStart = now
        windowStartMediaTime = mediaTime
        lastMediaTime = mediaTime
        displayedFrames = 0
        droppedFrames = 0
    }

    private mutating func accumulate(displayed: Int, dropped: Int, mediaTime: TimeInterval?) {
        displayedFrames += displayed
        droppedFrames += dropped
        guard let mediaTime else {
            return
        }
        if windowStartMediaTime == nil {
            windowStartMediaTime = mediaTime
        }
        lastMediaTime = mediaTime
    }

    private func advancedMediaSeconds() -> TimeInterval {
        guard let windowStartMediaTime, let lastMediaTime else {
            return 0
        }
        return max(0, lastMediaTime - windowStartMediaTime)
    }
}
