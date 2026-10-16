// MediaView.swift
// Full media card view for the expanded dashboard and Home tab.

import SwiftUI

struct MediaView: View {

    @ObservedObject var mediaManager: MediaManager

    var body: some View {
        if let media = mediaManager.currentMedia {
            activeMediaCard(media)
        } else {
            idleMediaCard
        }
    }

    // MARK: - Active Media Card

    private func activeMediaCard(_ media: MediaItem) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Album artwork or placeholder
                artworkView(media)
                    .frame(width: 52, height: 52)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                // Track details
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(media.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        AudioWaveView(isPlaying: media.isPlaying, color: .purple)
                    }

                    Text(media.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    if !media.album.isEmpty {
                        Text(media.album)
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Playback controls
                HStack(spacing: 12) {
                    Button {
                        mediaManager.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)

                    Button {
                        mediaManager.togglePlayPause()
                    } label: {
                        Image(systemName: media.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        mediaManager.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Progress bar and timestamps
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 3)

                        // Elapsed track
                        Capsule()
                            .fill(Color.purple)
                            .frame(width: max(0, geo.size.width * CGFloat(media.progress)), height: 3)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let fraction = max(0, min(1, value.location.x / geo.size.width))
                                let targetSeconds = media.duration * Double(fraction)
                                mediaManager.seek(to: targetSeconds)
                            }
                    )
                }
                .frame(height: 4)

                HStack {
                    Text(media.formattedElapsed)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))

                    Spacer()

                    Text(media.formattedDuration)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func artworkView(_ media: MediaItem) -> some View {
        Group {
            if let artwork = media.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note")
                        .font(.system(size: 20))
                        .foregroundStyle(.purple.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Idle Media Card

    private var idleMediaCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 44, height: 44)
                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing Playing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Play media in any browser or music app")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }
}
