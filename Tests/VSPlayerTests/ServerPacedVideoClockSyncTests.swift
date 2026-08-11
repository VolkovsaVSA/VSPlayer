//
//  ServerPacedVideoClockSyncTests.swift
//  VSPlayerTests
//
//  Created by Sergei Volkov on 2026/8/11.
//

@testable import VSPlayer
import CoreMedia
import XCTest

final class ServerPacedVideoClockSyncTests: XCTestCase {
    private var wallTime: TimeInterval = 1000

    private func makeServerPacedOptions(speed: Float = 4) -> VSOptions {
        let options = VSOptions()
        options.isServerPacedStream = true
        options.streamSpeedFactor = speed
        options.wallClock = { [unowned self] in self.wallTime }
        return options
    }

    private func makeClock(seconds: TimeInterval) -> VSClock {
        var clock = VSClock()
        clock.time = CMTime(seconds: seconds, preferredTimescale: 90_000)
        return clock
    }

    /// A speed-scaled stream holds `speed` times more frames per media-second than the display
    /// link can present, so frames behind the wall-time target must be discarded.
    func testVideoClockSync_serverPacedLateFrameIsDropped() {
        let options = makeServerPacedOptions()
        let clock = makeClock(seconds: 0)
        _ = options.videoClockSync(main: clock, nextVideoTime: 0, fps: 25, frameCount: 8)

        wallTime += 0.05
        let (diff, type) = options.videoClockSync(main: clock, nextVideoTime: 0.0125, fps: 25, frameCount: 8)

        XCTAssertLessThan(diff, 0)
        XCTAssertEqual(type, .dropNextFrame)
    }

    /// The server-paced path must not consult the main clock: it is re-anchored to every displayed
    /// frame and rounds each tick up to a whole frame, which runs playback fast.
    func testVideoClockSync_serverPacedIgnoresMainClock() {
        let options = makeServerPacedOptions()
        _ = options.videoClockSync(main: makeClock(seconds: 0), nextVideoTime: 0, fps: 25, frameCount: 8)

        wallTime += 0.05
        let (_, type) = options.videoClockSync(main: makeClock(seconds: 500), nextVideoTime: 0.0125, fps: 25, frameCount: 8)

        XCTAssertEqual(type, .dropNextFrame)
    }

    func testVideoClockSync_serverPacedDueFrameIsShown() {
        let options = makeServerPacedOptions()
        let clock = makeClock(seconds: 0)
        _ = options.videoClockSync(main: clock, nextVideoTime: 0, fps: 25, frameCount: 8)

        wallTime += 0.0125
        let (_, type) = options.videoClockSync(main: clock, nextVideoTime: 0.0125, fps: 25, frameCount: 8)

        XCTAssertEqual(type, .next)
    }

    /// Media time must advance with wall time, so a frame that is still ahead waits — at every
    /// speed. Taking it early runs playback fast and drains the decoded-frame queue.
    func testVideoClockSync_serverPacedEarlyFrameWaitsAtHighSpeed() {
        let options = makeServerPacedOptions(speed: 6)
        let clock = makeClock(seconds: 0)
        _ = options.videoClockSync(main: clock, nextVideoTime: 0, fps: 25, frameCount: 8)

        wallTime += 0.001
        let (_, type) = options.videoClockSync(main: clock, nextVideoTime: 0.0083, fps: 25, frameCount: 8)

        XCTAssertEqual(type, .remain)
    }

    func testVideoClockSync_serverPacedEarlyFrameWaitsAtNormalSpeed() {
        let options = makeServerPacedOptions(speed: 1)
        let clock = makeClock(seconds: 0)
        _ = options.videoClockSync(main: clock, nextVideoTime: 0, fps: 25, frameCount: 8)

        wallTime += 0.0333
        let (_, type) = options.videoClockSync(main: clock, nextVideoTime: 0.05, fps: 25, frameCount: 8)

        XCTAssertEqual(type, .remain)
    }

    func testVideoClockSync_liveStreamKeepsRemainBehaviour() {
        let options = VSOptions()
        let clock = makeClock(seconds: 10)

        let (_, type) = options.videoClockSync(main: clock, nextVideoTime: 10.5, fps: 25, frameCount: 8)

        XCTAssertEqual(type, .remain)
    }

    /// Live keeps its own behaviour: late frames are only dropped on every other evaluation.
    func testVideoClockSync_liveStreamKeepsDropBehaviour() {
        let options = VSOptions()
        let clock = makeClock(seconds: 10)

        let (_, first) = options.videoClockSync(main: clock, nextVideoTime: 9, fps: 25, frameCount: 8)
        let (_, second) = options.videoClockSync(main: clock, nextVideoTime: 9, fps: 25, frameCount: 8)

        XCTAssertEqual(first, .next)
        XCTAssertEqual(second, .dropNextFrame)
    }
}
