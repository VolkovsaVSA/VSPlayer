//
//  VSVideoPlayerViewBuilder.swift
//
//
//  Created by Ian Magallan Bosch on 17.03.24.
//

import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
enum VSVideoPlayerViewBuilder {
    @MainActor
    static func playbackControlView(config: VSVideoPlayer.Coordinator, spacing: CGFloat? = nil) -> some View {
        HStack(spacing: spacing) {
            // Playback controls don't need spacers for visionOS, since the controls are laid out in a HStack.
            #if os(xrOS)
            backwardButton(config: config)
            playButton(config: config)
            forwardButton(config: config)
            #else
            Spacer()
            backwardButton(config: config)
            Spacer()
            playButton(config: config)
            Spacer()
            forwardButton(config: config)
            Spacer()
            #endif
        }
    }

    @MainActor
    static func contentModeButton(config: VSVideoPlayer.Coordinator) -> some View {
        Button {
            config.isScaleAspectFill.toggle()
        } label: {
            Image(systemName: config.isScaleAspectFill ? "rectangle.arrowtriangle.2.inward" : "rectangle.arrowtriangle.2.outward")
        }
    }

    @MainActor
    static func subtitleButton(config: VSVideoPlayer.Coordinator) -> some View {
        MenuView(selection: Binding {
            config.subtitleModel.selectedSubtitleInfo?.subtitleID
        } set: { value in
            let info = config.subtitleModel.subtitleInfos.first { $0.subtitleID == value }
            config.subtitleModel.selectedSubtitleInfo = info
            if let info = info as? MediaPlayerTrack {
                // Image subtitles need a seek to be displayed in real time, so select track has to be used
                config.playerLayer?.player.select(track: info)
            }
        }) {
            Text("Off").tag(nil as String?)
            ForEach(config.subtitleModel.subtitleInfos, id: \.subtitleID) { track in
                Text(track.name).tag(track.subtitleID as String?)
            }
        } label: {
            Image(systemName: "text.bubble.fill")
        }
    }

    @MainActor
    static func playbackRateButton(playbackRate: Binding<Float>) -> some View {
        MenuView(selection: playbackRate) {
            ForEach([0.5, 1.0, 1.25, 1.5, 2.0] as [Float]) { value in
                // A text variable is needed, otherwise a lot of zeros are added automatically
                let text = "\(value) x"
                Text(text).tag(value)
            }
        } label: {
            Image(systemName: "gauge.with.dots.needle.67percent")
        }
    }

    @MainActor
    static func titleView(title: String, config: VSVideoPlayer.Coordinator) -> some View {
        HStack {
            Text(title)
                .font(.title3)
            ProgressView()
                .opacity(config.state == .buffering ? 1 : 0)
        }
    }

    @MainActor
    static func muteButton(config: VSVideoPlayer.Coordinator) -> some View {
        Button {
            config.isMuted.toggle()
        } label: {
            Image(systemName: config.isMuted ? speakerDisabledSystemName : speakerSystemName)
        }
        .shadow(color: .black, radius: 1)
    }

    static func infoButton(showVideoSetting: Binding<Bool>) -> some View {
        Button {
            showVideoSetting.wrappedValue.toggle()
        } label: {
            Image(systemName: "info.circle.fill")
        }
        // On the iOS simulator keyboardShortcut prevents VSVideoPlayer.Coordinator from being released. Real devices don't have this problem
        #if !os(tvOS)
        .keyboardShortcut("i", modifiers: [.command])
        #endif
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private extension VSVideoPlayerViewBuilder {
    static var playSystemName: String {
        #if os(xrOS)
        "play.fill"
        #else
        "play.circle.fill"
        #endif
    }

    static var pauseSystemName: String {
        #if os(xrOS)
        "pause.fill"
        #else
        "pause.circle.fill"
        #endif
    }

    static var speakerSystemName: String {
        #if os(xrOS)
        "speaker.fill"
        #else
        "speaker.wave.2.circle.fill"
        #endif
    }

    static var speakerDisabledSystemName: String {
        #if os(xrOS)
        "speaker.slash.fill"
        #else
        "speaker.slash.circle.fill"
        #endif
    }

    @MainActor
    @ViewBuilder
    static func backwardButton(config: VSVideoPlayer.Coordinator) -> some View {
        if config.playerLayer?.player.seekable ?? false {
            Button {
                config.skip(interval: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.largeTitle)
            }
            #if !os(tvOS)
            .keyboardShortcut(.leftArrow, modifiers: .none)
            #endif
        }
    }

    @MainActor
    @ViewBuilder
    static func forwardButton(config: VSVideoPlayer.Coordinator) -> some View {
        if config.playerLayer?.player.seekable ?? false {
            Button {
                config.skip(interval: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.largeTitle)
            }
            #if !os(tvOS)
            .keyboardShortcut(.rightArrow, modifiers: .none)
            #endif
        }
    }

    @MainActor
    static func playButton(config: VSVideoPlayer.Coordinator) -> some View {
        Button {
            if config.state.isPlaying {
                config.playerLayer?.pause()
            } else {
                config.playerLayer?.play()
            }
        } label: {
            Image(systemName: config.state == .error ? "play.slash.fill" : (config.state.isPlaying ? pauseSystemName : playSystemName))
                .font(.largeTitle)
        }
        #if os(xrOS)
        .contentTransition(.symbolEffect(.replace))
        #endif
        #if !os(tvOS)
        .keyboardShortcut(.space, modifiers: .none)
        #endif
    }
}
