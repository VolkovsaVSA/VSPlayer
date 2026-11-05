//
//  PlaybackMasterClock.swift
//  VSPlayer
//
//  Created by Sergei Volkov on 05.11.2026.
//

import Foundation

/// Which media clock reports the played second and drives seek.
enum PlaybackMasterClock {
    case video
    case audio

    /// Server-paced archive rewrites video timestamps onto a continuous timeline and leaves
    /// audio timestamps on the demuxer clock. The frame on screen follows the video clock, so
    /// that clock is the playback position even while audio is decoded and played.
    static func select(audioDisabled: Bool, serverPaced: Bool, audioStalled: Bool) -> PlaybackMasterClock {
        if audioDisabled || serverPaced || audioStalled {
            return .video
        }
        return .audio
    }
}
