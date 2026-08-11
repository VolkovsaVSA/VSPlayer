//
//  SpeedScaledFrameQueueTests.swift
//  VSPlayerTests
//
//  Created by Sergei Volkov on 2026/8/11.
//

@testable import VSPlayer
import CoreGraphics
import XCTest

final class SpeedScaledFrameQueueTests: XCTestCase {
    private func makeServerPacedOptions(speed: Float) -> VSOptions {
        let options = VSOptions()
        options.isServerPacedStream = true
        options.streamSpeedFactor = speed
        return options
    }

    private func frameMaxCount(_ options: VSOptions, isLive: Bool = true) -> UInt8 {
        options.videoFrameMaxCount(fps: 20, naturalSize: CGSize(width: 1920, height: 1080), isLive: isLive)
    }

    /// At 1x the stock queue must be kept: the render loop drains it once per display tick, and a
    /// larger queue only adds latency when no catch-up is needed.
    func testVideoFrameMaxCount_atNormalSpeedKeepsDefault() {
        XCTAssertEqual(frameMaxCount(makeServerPacedOptions(speed: 1)), 4)
        XCTAssertEqual(frameMaxCount(makeServerPacedOptions(speed: 1), isLive: false), 16)
    }

    /// The queue caps throughput at `capacity * displayTicks` frames per second, so an Nx stream
    /// needs at least N frames per tick.
    func testVideoFrameMaxCount_scalesWithStreamSpeed() {
        XCTAssertEqual(frameMaxCount(makeServerPacedOptions(speed: 4)), 8)
        XCTAssertEqual(frameMaxCount(makeServerPacedOptions(speed: 6)), 12)
        XCTAssertEqual(frameMaxCount(makeServerPacedOptions(speed: 8)), 16)
    }

    func testVideoFrameMaxCount_isCappedForExtremeSpeeds() {
        XCTAssertEqual(frameMaxCount(makeServerPacedOptions(speed: 32)), 16)
    }

    func testVideoFrameMaxCount_roundsFractionalSpeedUp() {
        XCTAssertEqual(frameMaxCount(makeServerPacedOptions(speed: 2.5)), 6)
    }

    /// Ordinary live and VOD playback must not be affected.
    func testVideoFrameMaxCount_liveStreamKeepsDefault() {
        let options = VSOptions()
        options.streamSpeedFactor = 6

        XCTAssertEqual(frameMaxCount(options), 4)
        XCTAssertEqual(frameMaxCount(options, isLive: false), 16)
    }
}
