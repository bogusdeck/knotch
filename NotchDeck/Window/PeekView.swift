// PeekView.swift
// Compact view shown when the user hovers over the notch.
// Displays live time + what's playing with audio wave.

import SwiftUI

struct PeekView: View {

    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var mediaManager: MediaManager

    var body: some View {
        HStack(spacing: 14) {
            // Clock — always shown
            clockSection

            Divider()
                .frame(height: 20)
                .overlay(.white.opacity(0.2))

            // Now playing section
            nowPlayingSection
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.requestExpand()
        }
    }

    // MARK: - Sub-views

    private var clockSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(Date(), format: .dateTime.hour().minute())
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(Date(), format: .dateTime.weekday(.wide))
                .font(.system(size: 10, weight: .regular))
                .opacity(0.6)
        }
    }

    private var nowPlayingSection: some View {
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
                                .imageScale(.small)
                                .foregroundStyle(media.brandColor)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .cornerRadius(4)
                } else {
                    Image(systemName: "music.note")
                        .imageScale(.small)
                        .foregroundStyle(media.brandColor)
                }

                Text("\(media.title) — \(media.artist)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                AudioWaveView(isPlaying: media.isPlaying, color: .purple)
            } else {
                Image(systemName: "music.note")
                    .imageScale(.small)
                    .opacity(0.4)
                Text("Nothing playing")
                    .font(.system(size: 11, weight: .regular))
                    .opacity(0.5)
                    .lineLimit(1)
            }
        }
    }
}
