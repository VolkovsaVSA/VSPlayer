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

    func testRemapPacket_absentPreviousTimestampFallsBackToOneFrame() {
        // AV_NOPTS_VALUE as the previous reference: the delta against a valid timestamp
        // does not fit Int64.
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let oneFrame = Int64(90_000 / 25)
        let noPts = makePacket(track: track, pts: Int64.min, dts: Int64.min)
        let valid = makePacket(track: track, pts: 1_000, dts: 1_000)

        remapper.remapPacket(noPts)
        remapper.remapPacket(valid)

        XCTAssertEqual(noPts.timestamp, 0)
        XCTAssertEqual(noPts.duration, oneFrame)
        XCTAssertEqual(valid.timestamp, oneFrame)
        XCTAssertEqual(valid.duration, oneFrame)
    }

    func testRemapPacket_extremeTimestampRangeStaysMonotonic() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let oneFrame = Int64(90_000 / 25)
        let minPacket = makePacket(track: track, pts: Int64.min, dts: Int64.min)
        let maxPacket = makePacket(track: track, pts: Int64.max, dts: Int64.max)
        let backToNormal = makePacket(track: track, pts: 42, dts: 42)

        remapper.remapPacket(minPacket)
        remapper.remapPacket(maxPacket)
        remapper.remapPacket(backToNormal)

        XCTAssertEqual(minPacket.timestamp, 0)
        XCTAssertEqual(maxPacket.timestamp, oneFrame)
        XCTAssertEqual(backToNormal.timestamp, oneFrame * 2)
        XCTAssertEqual(backToNormal.duration, oneFrame)
    }

    func testRemapPacket_alternatingGarbageAndValidTimestamps() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: 90_000), fps: 25)
        let oneFrame = Int64(90_000 / 25)
        let originals: [Int64] = [
            Int64.min, 0, Int64.min, oneFrame, Int64.max, oneFrame * 2, Int64.min, -1, Int64.min,
        ]
        var lastTimestamp: Int64 = -1
        for original in originals {
            let packet = makePacket(track: track, pts: original, dts: original)
            remapper.remapPacket(packet)
            XCTAssertGreaterThan(packet.timestamp, lastTimestamp, "original=\(original)")
            XCTAssertGreaterThan(packet.duration, 0, "original=\(original)")
            XCTAssertLessThanOrEqual(packet.duration, oneFrame * 2, "original=\(original)")
            lastTimestamp = packet.timestamp
        }
        // Every delta collapses to one frame: no valid pair of consecutive timestamps survives.
        XCTAssertEqual(lastTimestamp, oneFrame * Int64(originals.count - 1))
    }

    func testRemapPacket_hugeFrameDurationDoesNotOverflow() {
        let remapper = MediaTimelinePtsRemapper()
        let track = makeVideoTrack(timebase: Timebase(num: 1, den: Int32.max), fps: 0)
        let oneFrame = Int64(Int32.max)
        let originals: [Int64] = [Int64.min, 0, Int64.max, oneFrame, Int64.min]
        var lastTimestamp: Int64 = -1
        for original in originals {
            let packet = makePacket(track: track, pts: original, dts: original)
            remapper.remapPacket(packet)
            XCTAssertGreaterThan(packet.timestamp, lastTimestamp, "original=\(original)")
            XCTAssertEqual(packet.duration, oneFrame, "original=\(original)")
            lastTimestamp = packet.timestamp
        }
        XCTAssertEqual(lastTimestamp, oneFrame * Int64(originals.count - 1))
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
