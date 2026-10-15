// AppleScriptMediaProvider.swift
// Media provider backend using AppleScript for Spotify and Apple Music.

import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "AppleScriptMediaProvider")

@MainActor
final class AppleScriptMediaProvider: MediaProvider {

    private(set) var currentMedia: MediaItem? = nil
    var isAvailable: Bool { true }

    private var pollTimer: Task<Void, Never>?
    private var onChangeCallback: (@MainActor (MediaItem?) -> Void)?

    // MARK: - Observation

    func startObserving(onChange: @escaping @MainActor (MediaItem?) -> Void) {
        self.onChangeCallback = onChange
        pollTimer?.cancel()

        pollTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.queryNowPlaying()
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s interval
            }
        }
    }

    func stopObserving() {
        pollTimer?.cancel()
        pollTimer = nil
        onChangeCallback = nil
    }

    // MARK: - Query

    func queryNowPlaying() async {
        // Only run AppleScript if Spotify or Music is actively running (0% idle CPU)
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty

        var newItem: MediaItem? = nil

        if isSpotifyRunning {
            newItem = await querySpotify()
        } else if isMusicRunning {
            newItem = await queryAppleMusic()
        }

        if newItem != currentMedia {
            currentMedia = newItem
            onChangeCallback?(newItem)
        }
    }

    private func querySpotify() async -> MediaItem? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                set pState to player state as string
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDuration to (duration of current track) / 1000
                set tPosition to player position
                return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDuration & "|||" & tPosition
            end tell
        else
            return ""
        end if
        """

        guard let output = try? await CommandRunner.runAppleScript(script), !output.isEmpty else {
            return nil
        }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let state = parts[0].lowercased()
        let name = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4]) ?? 0.0
        let position = Double(parts[5]) ?? 0.0

        return MediaItem(
            title: name,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: position,
            isPlaying: (state == "playing"),
            bundleIdentifier: "com.spotify.client",
            artworkData: nil
        )
    }

    private func queryAppleMusic() async -> MediaItem? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                set pState to player state as string
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                set tDuration to duration of current track
                set tPosition to player position
                return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDuration & "|||" & tPosition
            end tell
        else
            return ""
        end if
        """

        guard let output = try? await CommandRunner.runAppleScript(script), !output.isEmpty else {
            return nil
        }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let state = parts[0].lowercased()
        let name = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4]) ?? 0.0
        let position = Double(parts[5]) ?? 0.0

        return MediaItem(
            title: name,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: position,
            isPlaying: (state == "playing"),
            bundleIdentifier: "com.apple.Music",
            artworkData: nil
        )
    }

    // MARK: - Playback Controls

    func play() async {
        if let bundle = currentMedia?.bundleIdentifier, bundle == "com.apple.Music" {
            _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to play")
        } else {
            _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to play")
        }
        await queryNowPlaying()
    }

    func pause() async {
        if let bundle = currentMedia?.bundleIdentifier, bundle == "com.apple.Music" {
            _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to pause")
        } else {
            _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to pause")
        }
        await queryNowPlaying()
    }

    func togglePlayPause() async {
        if let bundle = currentMedia?.bundleIdentifier, bundle == "com.apple.Music" {
            _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to playpause")
        } else {
            _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to playpause")
        }
        await queryNowPlaying()
    }

    func nextTrack() async {
        if let bundle = currentMedia?.bundleIdentifier, bundle == "com.apple.Music" {
            _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to next track")
        } else {
            _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to next track")
        }
        await queryNowPlaying()
    }

    func previousTrack() async {
        if let bundle = currentMedia?.bundleIdentifier, bundle == "com.apple.Music" {
            _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to previous track")
        } else {
            _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to previous track")
        }
        await queryNowPlaying()
    }

    func seek(to seconds: Double) async {
        if let bundle = currentMedia?.bundleIdentifier, bundle == "com.apple.Music" {
            _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to set player position to \(seconds)")
        } else {
            _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to set player position to \(seconds)")
        }
        await queryNowPlaying()
    }
}
