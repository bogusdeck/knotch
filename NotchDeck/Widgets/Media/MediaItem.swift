// MediaItem.swift
// Model representing the currently playing media item.

import AppKit
import Foundation
import SwiftUI

struct MediaItem: Sendable, Equatable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let isPlaying: Bool
    let bundleIdentifier: String?
    var artworkData: Data?
    let artworkUrl: String?

    init(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        isPlaying: Bool,
        bundleIdentifier: String? = nil,
        artworkData: Data? = nil,
        artworkUrl: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.isPlaying = isPlaying
        self.bundleIdentifier = bundleIdentifier
        self.artworkData = artworkData
        self.artworkUrl = artworkUrl
    }

    /// Actual album artwork image (from raw data, if present)
    var artwork: NSImage? {
        if let artworkData, let img = NSImage(data: artworkData) {
            return img
        }
        return nil
    }

    /// Application icon fallback
    var appIcon: NSImage? {
        if let bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }

    /// Indicates whether true album artwork is available (either embedded data or image URL)
    var hasArtwork: Bool {
        artworkData != nil || (artworkUrl != nil && !(artworkUrl?.isEmpty ?? true))
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

    var isSpotify: Bool {
        if let bundle = bundleIdentifier?.lowercased(), bundle.contains("spotify") {
            return true
        }
        if let url = artworkUrl?.lowercased(), url.contains("scdn.co") || url.contains("spotify") {
            return true
        }
        return false
    }

    var isAppleMusic: Bool {
        if let bundle = bundleIdentifier?.lowercased(), bundle.contains("music") {
            return true
        }
        return false
    }

    var appDisplayName: String {
        if isSpotify { return "Spotify" }
        if isAppleMusic { return "Apple Music" }
        return "Music"
    }

    var brandColor: Color {
        if isSpotify {
            return Color(red: 0.11, green: 0.73, blue: 0.33)
        }
        if isAppleMusic {
            return Color(red: 0.99, green: 0.24, blue: 0.27)
        }
        return Color.purple
    }
}
