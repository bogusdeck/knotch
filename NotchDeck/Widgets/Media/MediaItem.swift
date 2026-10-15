// MediaItem.swift
// Model representing the currently playing media item.

import AppKit
import Foundation

struct MediaItem: Sendable, Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let isPlaying: Bool
    let bundleIdentifier: String?
    let artworkData: Data?

    var artwork: NSImage? {
        guard let artworkData else { return nil }
        return NSImage(data: artworkData)
    }

    var progress: Double {
        guard duration > 0 else { return 0.0 }
        return min(1.0, max(0.0, elapsedTime / duration))
    }

    var formattedElapsed: String {
        formatTime(elapsedTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
