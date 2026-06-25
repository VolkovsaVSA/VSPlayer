@testable import VSPlayer
import XCTest

class VSPlayerLayerTest: XCTestCase {
    private var readyToPlayExpectation: XCTestExpectation?
    override func setUp() {
        VSOptions.secondPlayerType = VSMEPlayer.self
        VSOptions.isSecondOpen = true
        VSOptions.isAccurateSeek = true
    }

    func testPlayerLayer() {
        if let path = Bundle(for: type(of: self)).path(forResource: "h264", ofType: "MP4") {
            set(path: path)
        }
//        if let path = Bundle(for: type(of: self)).path(forResource: "google-help-vr", ofType: "mp4") {
//            set(path: path)
//        }
        if let path = Bundle(for: type(of: self)).path(forResource: "mjpeg", ofType: "flac") {
            set(path: path)
        }
        if let path = Bundle(for: type(of: self)).path(forResource: "hevc", ofType: "mkv") {
            set(path: path)
        }
    }

    func set(path: String) {
        let options = VSOptions()
        let playerLayer = VSPlayerLayer(url: URL(fileURLWithPath: path), options: options)
        playerLayer.delegate = self
        XCTAssertEqual(playerLayer.state, .preparing)
        readyToPlayExpectation = expectation(description: "openVideo")
        waitForExpectations(timeout: 2) { _ in
            XCTAssert(playerLayer.player.isReadyToPlay == true)
            XCTAssertEqual(playerLayer.state, .readyToPlay)
            playerLayer.play()
            playerLayer.pause()
            XCTAssertEqual(playerLayer.state, .paused)
            let seekExpectation = self.expectation(description: "seek")
            playerLayer.seek(time: 2, autoPlay: true) { _ in
                seekExpectation.fulfill()
            }
            XCTAssertEqual(playerLayer.state, .buffering)
            self.waitForExpectations(timeout: 1000) { _ in
                playerLayer.finish(player: playerLayer.player, error: nil)
                XCTAssertEqual(playerLayer.state, .playedToTheEnd)
                playerLayer.stop()
                XCTAssertEqual(playerLayer.state, .initialized)
            }
        }
    }
}

extension VSPlayerLayerTest: VSPlayerLayerDelegate {
    func player(layer _: VSPlayerLayer, state: VSPlayerState) {
        if state == .readyToPlay {
            readyToPlayExpectation?.fulfill()
        }
    }

    func player(layer _: VSPlayerLayer, currentTime _: TimeInterval, totalTime _: TimeInterval) {}

    func player(layer _: VSPlayerLayer, finish _: Error?) {}
    func player(layer _: VSPlayerLayer, bufferedCount: Int, consumeTime _: TimeInterval) {
        if bufferedCount > 0 {
            XCTFail()
        }
    }
}
