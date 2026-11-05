//
//  PlaybackMasterClockTests.swift
//  VSPlayerTests
//
//  Created by Sergei Volkov on 05.11.2026.
//

@testable import VSPlayer
import XCTest

final class PlaybackMasterClockTests: XCTestCase {
    func testSelect_serverPacedWithAudio_usesVideoClock() {
        XCTAssertEqual(
            PlaybackMasterClock.select(audioDisabled: false, serverPaced: true, audioStalled: false),
            .video
        )
    }

    func testSelect_audioDisabled_usesVideoClock() {
        XCTAssertEqual(
            PlaybackMasterClock.select(audioDisabled: true, serverPaced: false, audioStalled: false),
            .video
        )
    }

    func testSelect_audioStalled_usesVideoClock() {
        XCTAssertEqual(
            PlaybackMasterClock.select(audioDisabled: false, serverPaced: false, audioStalled: true),
            .video
        )
    }

    func testSelect_liveAudio_usesAudioClock() {
        XCTAssertEqual(
            PlaybackMasterClock.select(audioDisabled: false, serverPaced: false, audioStalled: false),
            .audio
        )
    }
}
