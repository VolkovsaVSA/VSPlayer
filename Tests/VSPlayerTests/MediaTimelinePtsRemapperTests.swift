//
//  MediaTimelinePtsRemapperTests.swift
//  VSPlayerTests
//
//  Created by Sergei Volkov on 2026/8/11.
//

@testable import VSPlayer
import FFmpegKit
import Libavcodec
import Libavformat
import XCTest

final class MediaTimelinePtsRemapperTests: XCTestCase {
    func testRemapPacket_preservesOneFrameDeltas() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let packet0 = makePacket(track: track, pts: 1_000_000, dts: 1_000_000)
        let packet1 = makePacket(track: track, pts: 1_003_600, dts: 1_003_600)

        remapper.remapPacket(packet0)
        remapper.remapPacket(packet1)

        let frameDuration = Int64(90_000 / 25)
        XCTAssertEqual(packet0.timestamp, 0)
        XCTAssertEqual(packet0.duration, frameDuration)
        XCTAssertEqual(packet1.timestamp, frameDuration)
        XCTAssertEqual(packet1.duration, frameDuration)
    }

    func testRemapPacket_preservesCompressedMediaDeltas() {
        // Speed-scaled stream: full frame density with compressed DTS (N frames packed into
        // EXTINF/N). Forcing 1/fps would stretch the picture back to 1x.
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let oneFrame = Int64(90_000 / 25)
        let compressedDelta = oneFrame / 4
        var timestamps: [Int64] = []
        var durations: [Int64] = []
        for index in 0 ..< 8 {
            let pts = Int64(index) * compressedDelta
            let packet = makePacket(track: track, pts: pts, dts: pts)
            remapper.remapPacket(packet)
            timestamps.append(packet.timestamp)
            durations.append(packet.duration)
        }
        XCTAssertEqual(timestamps[0], 0)
        XCTAssertEqual(durations[0], oneFrame)
        for index in 1 ..< 8 {
            XCTAssertEqual(durations[index], compressedDelta, "duration index=\(index)")
            XCTAssertEqual(
                timestamps[index] - timestamps[index - 1],
                index == 1 ? oneFrame : compressedDelta,
                "gap before index=\(index)"
            )
        }
        XCTAssertEqual(timestamps[7], oneFrame + compressedDelta * 6)
    }

    func testRemapPacket_collapsesLargeSegmentGaps() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let oneFrame = Int64(90_000 / 25)
        let packet0 = makePacket(track: track, pts: 0, dts: 0)
        let packet1 = makePacket(track: track, pts: 1_000_000, dts: 1_000_000)
        let packet2 = makePacket(track: track, pts: 2_000_000, dts: 2_000_000)

        remapper.remapPacket(packet0)
        remapper.remapPacket(packet1)
        remapper.remapPacket(packet2)

        XCTAssertEqual(packet0.timestamp, 0)
        XCTAssertEqual(packet1.timestamp, oneFrame)
        XCTAssertEqual(packet2.timestamp, oneFrame * 2)
    }

    func testRemapPacket_keepsAllPackets() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let oneFrame = Int64(90_000 / 25)
        var lastTimestamp: Int64 = -1
        for index in 0 ..< 8 {
            let pts = Int64(index) * oneFrame
            let packet = makePacket(track: track, pts: pts, dts: pts)
            remapper.remapPacket(packet)
            if lastTimestamp >= 0 {
                XCTAssertEqual(packet.timestamp - lastTimestamp, oneFrame)
            }
            lastTimestamp = packet.timestamp
        }
        XCTAssertEqual(lastTimestamp, oneFrame * 7)
    }

    func testReset_restartsTimeline() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        remapper.remapPacket(makePacket(track: track, pts: 500, dts: 500))
        remapper.reset()
        let packet = makePacket(track: track, pts: 900, dts: 900)
        remapper.remapPacket(packet)
        XCTAssertEqual(packet.timestamp, 0)
    }

    func testTimestampForDecodedFrame_usesPacketTimeline() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let packet = makePacket(track: track, pts: 42, dts: 42)
        remapper.remapPacket(packet)
        let remapped = remapper.timestampForDecodedFrame(packet: packet, fallbackDuration: 0)
        XCTAssertEqual(remapped.timestamp, 0)
        XCTAssertEqual(remapped.duration, Int64(90_000 / 25))
    }

    private func makeVideoTrack(timebase: Timebase, fps: Float) -> FFmpegAssetTrack {
        var codecpar = AVCodecParameters()
        codecpar.codec_type = AVMEDIA_TYPE_VIDEO
        codecpar.codec_id = AV_CODEC_ID_H264
        codecpar.width = 640
        codecpar.height = 480
        let track = FFmpegAssetTrack(codecpar: codecpar)!
        track.timebase = timebase
        track.nominalFrameRate = fps
        return track
    }

    private func makePacket(track: FFmpegAssetTrack, pts: Int64, dts: Int64) -> Packet {
        let packet = Packet()
        packet.assetTrack = track
        packet.corePacket?.pointee.pts = pts
        packet.corePacket?.pointee.dts = dts
        packet.corePacket?.pointee.duration = 0
        packet.timestamp = pts
        packet.duration = 0
        return packet
    }
}
