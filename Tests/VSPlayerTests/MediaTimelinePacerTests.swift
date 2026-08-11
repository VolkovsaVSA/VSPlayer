//
//  MediaTimelinePacerTests.swift
//  VSPlayerTests
//
//  Created by Sergei Volkov on 2026/8/11.
//

@testable import VSPlayer
import XCTest

final class MediaTimelinePacerTests: XCTestCase {
    func testDecide_firstFrameAnchorsAndPresents() {
        var pacer = MediaTimelinePacer()

        let (decision, diff) = pacer.decide(frameTime: 12.5, now: 100)

        XCTAssertEqual(decision, .present)
        XCTAssertEqual(diff, 0)
    }

    func testDecide_frameAheadOfTargetWaits() {
        var pacer = MediaTimelinePacer()
        _ = pacer.decide(frameTime: 0, now: 100)

        let (decision, diff) = pacer.decide(frameTime: 0.05, now: 100.02)

        XCTAssertEqual(decision, .wait)
        XCTAssertEqual(diff, 0.03, accuracy: 1e-6)
    }

    func testDecide_frameBehindTargetIsDiscarded() {
        var pacer = MediaTimelinePacer()
        _ = pacer.decide(frameTime: 0, now: 100)

        let (decision, diff) = pacer.decide(frameTime: 0.02, now: 100.05)

        XCTAssertEqual(decision, .discard)
        XCTAssertEqual(diff, -0.03, accuracy: 1e-6)
    }

    func testDecide_frameWithinToleranceIsPresented() {
        var pacer = MediaTimelinePacer()
        _ = pacer.decide(frameTime: 0, now: 100)

        let (decision, _) = pacer.decide(frameTime: 0.0501, now: 100.05)

        XCTAssertEqual(decision, .present)
    }

    /// A pause or a long stall must not flush the queue or freeze the picture: the timeline is
    /// re-anchored to the frame at hand.
    func testDecide_largeDriftReanchors() {
        var pacer = MediaTimelinePacer()
        _ = pacer.decide(frameTime: 0, now: 100)

        let (decision, diff) = pacer.decide(frameTime: 0.05, now: 110)

        XCTAssertEqual(decision, .present)
        XCTAssertEqual(diff, 0)

        // The new anchor is (0.05, 110), so a frame one interval later is again ahead.
        let (next, _) = pacer.decide(frameTime: 0.1, now: 110.02)
        XCTAssertEqual(next, .wait)
    }

    func testReset_dropsAnchor() {
        var pacer = MediaTimelinePacer()
        _ = pacer.decide(frameTime: 0, now: 100)
        pacer.reset()

        let (decision, _) = pacer.decide(frameTime: 50, now: 100.02)

        XCTAssertEqual(decision, .present)
    }

    /// 1x: 20fps media presented by a 30Hz display link. Rounding each tick up to a whole frame
    /// ran media time at 1.5x; pacing must keep it at 1.0.
    func testPacing_mediaSlowerThanDisplayLinkRunsAtWallSpeed() {
        assertMediaRate(mediaFPS: 20, displayHz: 30)
    }

    /// 4x: 80fps media on a 60Hz display link — the rounding that made it look like 6x.
    func testPacing_fourTimesSpeedOnSixtyHertzRunsAtWallSpeed() {
        assertMediaRate(mediaFPS: 80, displayHz: 60)
    }

    /// 6x: 120fps media on a 20Hz display link, an exact multiple that was already correct and
    /// must stay correct.
    func testPacing_mediaFasterThanDisplayLinkRunsAtWallSpeed() {
        assertMediaRate(mediaFPS: 120, displayHz: 20)
    }

    /// Feeds a full second of frames tick by tick and checks how far media time advanced.
    private func assertMediaRate(
        mediaFPS: Double,
        displayHz: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var pacer = MediaTimelinePacer()
        let spacing = 1 / mediaFPS
        let tick = 1 / displayHz
        let start: TimeInterval = 1000
        var nextFrameIndex = 0
        var lastPresented: TimeInterval?

        // One tick past a full second, so the last tick lands exactly on `start + 1`.
        for tickIndex in 0 ... Int(displayHz) {
            let now = start + Double(tickIndex) * tick
            // Drain every frame that is already behind the target, like getVideoOutputRender.
            while true {
                let frameTime = Double(nextFrameIndex) * spacing
                let (decision, _) = pacer.decide(frameTime: frameTime, now: now)
                if decision == .wait {
                    break
                }
                nextFrameIndex += 1
                lastPresented = frameTime
                if decision == .present {
                    break
                }
            }
        }

        let advanced = (lastPresented ?? 0) - 0
        XCTAssertEqual(advanced, 1, accuracy: 2 * spacing, file: file, line: line)
    }
}
