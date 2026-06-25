//
//  EmbedDataSouce.swift
//  VSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
import Libavcodec
import Libavutil

extension FFmpegAssetTrack: SubtitleInfo {
    public var subtitleID: String {
        String(trackID)
    }
}

extension FFmpegAssetTrack: VSSubtitleProtocol {
    public func search(for time: TimeInterval) -> [SubtitlePart] {
        subtitle?.outputRenderQueue.search { item -> Bool in
            item.part == time
        }.map(\.part) ?? []
    }
}

extension VSMEPlayer: SubtitleDataSouce {
    public var infos: [any SubtitleInfo] {
        tracks(mediaType: .subtitle).compactMap { $0 as? (any SubtitleInfo) }
    }
}
