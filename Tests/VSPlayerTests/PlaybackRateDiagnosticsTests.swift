//
//  PlaybackRateDiagnosticsTests.swift
//  VSPlayerTests
//
//  Created by Sergei Volkov on 2026/8/11.
//

@testable import VSPlayer
import XCTest

final class PlaybackRateDiagnosticsTests: XCTestCase {
    func testRecord_returnsNothingBeforeWindowElapses() {
        var diagnostics = PlaybackRateDiagnostics()

        XCTAssertNil(diagnostics.record(displayed: 1, dropped: 3, mediaTime: 100, speedFactor: 4, now: 0))
        XCTAssertNil(diagnostics.record(displayed: 1, dropped: 3, mediaTime: 100.04, speedFactor: 4, now: 0.5))
    }

    func testRecord_aggregatesCountersOverTheWindow() throws {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 1, dropped: 3, mediaTime: 100, speedFactor: 4, now: 0)
        _ = diagnostics.record(displayed: 1, dropped: 3, mediaTime: 100.04, speedFactor: 4, now: 0.5)
        let snapshot = try XCTUnwrap(diagnostics.record(displayed: 1, dropped: 3, mediaTime: 100.08, speedFactor: 4, now: 1))

        XCTAssertEqual(snapshot.interval, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.displayedFrames, 3)
        XCTAssertEqual(snapshot.droppedFrames, 9)
        XCTAssertEqual(snapshot.consumedFrames, 12)
        XCTAssertEqual(snapshot.consumedFPS, 12, accuracy: 0.0001)
        XCTAssertEqual(snapshot.mediaSecondsAdvanced, 0.08, accuracy: 0.0001)
    }

    /// A measured decoder ceiling: at 6x the stream carries ~146 frames per media-second, the
    /// player only pulls ~105 per wall-second, so media time runs at 0.72 of wall time and the
    /// viewer sees ~4.3x instead of 6x.
    func testSnapshot_reportsEffectiveSpeedBelowRequestedSpeed() throws {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 0, dropped: 0, mediaTime: 0, speedFactor: 6, now: 0)
        let snapshot = try XCTUnwrap(diagnostics.record(displayed: 60, dropped: 45, mediaTime: 0.72, speedFactor: 6, now: 1))

        XCTAssertEqual(snapshot.consumedFPS, 105, accuracy: 0.0001)
        XCTAssertEqual(snapshot.mediaRate, 0.72, accuracy: 0.0001)
        XCTAssertEqual(snapshot.effectiveSpeed, 4.32, accuracy: 0.0001)
    }

    func testSnapshot_reportsRequestedSpeedWhenPlayerKeepsUp() throws {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 0, dropped: 0, mediaTime: 0, speedFactor: 6, now: 0)
        let snapshot = try XCTUnwrap(diagnostics.record(displayed: 60, dropped: 86, mediaTime: 1, speedFactor: 6, now: 1))

        XCTAssertEqual(snapshot.mediaRate, 1, accuracy: 0.0001)
        XCTAssertEqual(snapshot.effectiveSpeed, 6, accuracy: 0.0001)
    }

    func testRecord_startsNewWindowWithoutDoubleCounting() throws {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 10, dropped: 10, mediaTime: 0, speedFactor: 4, now: 0)
        _ = try XCTUnwrap(diagnostics.record(displayed: 10, dropped: 10, mediaTime: 1, speedFactor: 4, now: 1))
        let second = try XCTUnwrap(diagnostics.record(displayed: 5, dropped: 1, mediaTime: 2, speedFactor: 4, now: 2))

        XCTAssertEqual(second.displayedFrames, 5)
        XCTAssertEqual(second.droppedFrames, 1)
        XCTAssertEqual(second.mediaSecondsAdvanced, 1, accuracy: 0.0001)
    }

    /// A seek rewinds media time; the window must not report a negative rate.
    func testRecord_clampsBackwardsMediaJump() throws {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 1, dropped: 0, mediaTime: 100, speedFactor: 4, now: 0)
        let snapshot = try XCTUnwrap(diagnostics.record(displayed: 1, dropped: 0, mediaTime: 10, speedFactor: 4, now: 1))

        XCTAssertEqual(snapshot.mediaSecondsAdvanced, 0, accuracy: 0.0001)
        XCTAssertEqual(snapshot.effectiveSpeed, 0, accuracy: 0.0001)
    }

    /// Ticks that produced no frame must not move the media anchor.
    func testRecord_ignoresTicksWithoutFrame() throws {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 0, dropped: 0, mediaTime: nil, speedFactor: 4, now: 0)
        _ = diagnostics.record(displayed: 1, dropped: 0, mediaTime: 50, speedFactor: 4, now: 0.5)
        let snapshot = try XCTUnwrap(diagnostics.record(displayed: 1, dropped: 0, mediaTime: 51, speedFactor: 4, now: 1))

        XCTAssertEqual(snapshot.mediaSecondsAdvanced, 1, accuracy: 0.0001)
    }

    func testReset_dropsPendingWindow() {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 1, dropped: 1, mediaTime: 0, speedFactor: 4, now: 0)
        diagnostics.reset()

        XCTAssertNil(diagnostics.record(displayed: 1, dropped: 1, mediaTime: 0, speedFactor: 4, now: 0.9))
    }

    func testLogLine_containsMeasuredValues() throws {
        var diagnostics = PlaybackRateDiagnostics()

        _ = diagnostics.record(displayed: 0, dropped: 0, mediaTime: 0, speedFactor: 6, now: 0)
        let snapshot = try XCTUnwrap(diagnostics.record(displayed: 60, dropped: 45, mediaTime: 0.72, speedFactor: 6, now: 1))

        let line = snapshot.logLine
        XCTAssertTrue(line.contains("speed=6.0"), line)
        XCTAssertTrue(line.contains("effective=4.32x"), line)
        XCTAssertTrue(line.contains("consumed=105.0fps"), line)
        XCTAssertTrue(line.contains("displayed=60.0fps"), line)
        XCTAssertTrue(line.contains("dropped=45.0fps"), line)
    }
}
