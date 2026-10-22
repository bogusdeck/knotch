// MediaWidget.swift
// NotchWidget wrapper for the Media playback feature.

import SwiftUI

@MainActor
final class MediaWidget: NotchWidget {

    let id: String = "media"
    let title: String = "Media"

    let mediaManager: MediaManager

    init(mediaManager: MediaManager) {
        self.mediaManager = mediaManager
    }

    func compactView() -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                if let media = mediaManager.currentMedia {
                    if let artwork = media.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 18, height: 18)
                            .cornerRadius(4)
                    } else if let urlStr = media.artworkUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 11))
                                    .foregroundStyle(media.brandColor)
                            }
                        }
                        .frame(width: 18, height: 18)
                        .cornerRadius(4)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 11))
                            .foregroundStyle(media.brandColor)
                    }

                    Text("\(media.title) • \(media.artist)")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)

                    AudioWaveView(isPlaying: media.isPlaying, color: .purple)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                        .opacity(0.4)
                    Text("Nothing playing")
                        .font(.system(size: 11))
                        .opacity(0.5)
                }
            }
        )
    }

    func expandedView() -> AnyView {
        AnyView(
            MediaView(mediaManager: mediaManager)
        )
    }
}
