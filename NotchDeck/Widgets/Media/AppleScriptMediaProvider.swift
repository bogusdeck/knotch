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
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty

        // 1. Check Spotify if actively playing
        if isSpotifyRunning, let spotify = await querySpotify(), spotify.isPlaying {
            updateItem(spotify)
            return
        }

        // 2. Check Apple Music if actively playing
        if isMusicRunning, let music = await queryAppleMusic(), music.isPlaying {
            updateItem(music)
            return
        }

        // 3. Check Zen Browser
        let isZenRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "app.zen-browser.zen").isEmpty
        if isZenRunning, let zen = await queryZen() {
            updateItem(zen)
            return
        }

        // 4. Check Safari
        let isSafariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        if isSafariRunning, let safari = await querySafari() {
            updateItem(safari)
            return
        }

        // 5. Check Google Chrome
        let isChromeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty
        if isChromeRunning, let chrome = await queryChrome() {
            updateItem(chrome)
            return
        }

        // 6. Check Arc
        let isArcRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "company.thebrowser.Browser").isEmpty
        if isArcRunning, let arc = await queryArc() {
            updateItem(arc)
            return
        }

        // 7. Check Brave
        let isBraveRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.brave.Browser").isEmpty
        if isBraveRunning, let brave = await queryBrave() {
            updateItem(brave)
            return
        }

        // 8. Fallback to paused Spotify or Apple Music
        if isSpotifyRunning, let spotify = await querySpotify() {
            updateItem(spotify)
            return
        }
        if isMusicRunning, let music = await queryAppleMusic() {
            updateItem(music)
            return
        }

        updateItem(nil)
    }

    private func updateItem(_ item: MediaItem?) {
        if item != currentMedia {
            currentMedia = item
            onChangeCallback?(item)
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

    private func queryZen() async -> MediaItem? {
        let script = """
        if application "Zen" is running then
            tell application "Zen"
                set winNames to name of every window
                repeat with wName in winNames
                    if wName is not "" and (wName contains "YouTube" or wName contains "Hotstar" or wName contains "Netflix" or wName contains "Spotify" or wName contains "SoundCloud" or wName contains "Music" or wName contains "video" or wName contains "Video") then
                        return wName as string
                    end if
                end repeat
                if (count of winNames) > 0 and item 1 of winNames is not "" then
                    return item 1 of winNames as string
                end if
            end tell
        end if
        return ""
        """

        guard let output = try? await CommandRunner.runAppleScript(script), !output.isEmpty else {
            return nil
        }

        return parseBrowserTitle(output, bundleId: "app.zen-browser.zen", appName: "Zen Browser")
    }

    private func querySafari() async -> MediaItem? {
        let script = """
        if application "Safari" is running then
            tell application "Safari"
                if (count of windows) > 0 then
                    set tName to name of current tab of front window
                    return tName as string
                end if
            end tell
        end if
        return ""
        """

        guard let output = try? await CommandRunner.runAppleScript(script), !output.isEmpty else {
            return nil
        }

        return parseBrowserTitle(output, bundleId: "com.apple.Safari", appName: "Safari")
    }

    private func queryChrome() async -> MediaItem? {
        let script = """
        if application "Google Chrome" is running then
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    set tName to title of active tab of front window
                    return tName as string
                end if
            end tell
        end if
        return ""
        """

        guard let output = try? await CommandRunner.runAppleScript(script), !output.isEmpty else {
            return nil
        }

        return parseBrowserTitle(output, bundleId: "com.google.Chrome", appName: "Google Chrome")
    }

    private func queryArc() async -> MediaItem? {
        let script = """
        if application "Arc" is running then
            tell application "Arc"
                if (count of windows) > 0 then
                    set tName to title of active tab of front window
                    return tName as string
                end if
            end tell
        end if
        return ""
        """

        guard let output = try? await CommandRunner.runAppleScript(script), !output.isEmpty else {
            return nil
        }

        return parseBrowserTitle(output, bundleId: "company.thebrowser.Browser", appName: "Arc")
    }

    private func queryBrave() async -> MediaItem? {
        let script = """
        if application "Brave Browser" is running then
            tell application "Brave Browser"
                if (count of windows) > 0 then
                    set tName to title of active tab of front window
                    return tName as string
                end if
            end tell
        end if
        return ""
        """

        guard let output = try? await CommandRunner.runAppleScript(script), !output.isEmpty else {
            return nil
        }

        return parseBrowserTitle(output, bundleId: "com.brave.Browser", appName: "Brave")
    }

    private func parseBrowserTitle(_ raw: String, bundleId: String, appName: String) -> MediaItem? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower == "zen browser" || lower == "new tab" || lower == "start page" || lower == "zen" {
            return nil
        }

        var cleanTitle = trimmed
        var artist = appName

        let suffixes = [" - YouTube", " - SoundCloud", " - Netflix", " - JioHotstar", " | JioHotstar", " - Spotify", " - Twitch"]
        for suffix in suffixes {
            if cleanTitle.hasSuffix(suffix) {
                cleanTitle = String(cleanTitle.dropLast(suffix.count))
                artist = suffix.trimmingCharacters(in: CharacterSet(charactersIn: " -|"))
                break
            }
        }

        if cleanTitle.contains(" - ") {
            let parts = cleanTitle.components(separatedBy: " - ")
            if parts.count >= 2 {
                artist = parts[0].trimmingCharacters(in: .whitespaces)
                cleanTitle = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            }
        }

        return MediaItem(
            title: cleanTitle,
            artist: artist,
            album: appName,
            duration: 0.0,
            elapsedTime: 0.0,
            isPlaying: true,
            bundleIdentifier: bundleId,
            artworkData: nil
        )
    }

    // MARK: - Playback Controls

    private func sendSystemMediaKey(_ key: Int32) {
        let down = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((key << 16) | (0xa << 8)),
            data2: -1
        )
        let up = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: Int((key << 16) | (0xb << 8)),
            data2: -1
        )
        down?.cgEvent?.post(tap: .cghidEventTap)
        up?.cgEvent?.post(tap: .cghidEventTap)
    }

    func play() async {
        if let bundle = currentMedia?.bundleIdentifier {
            if bundle == "com.apple.Music" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to play")
            } else if bundle == "com.spotify.client" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to play")
            } else {
                sendSystemMediaKey(16)
            }
        } else {
            sendSystemMediaKey(16)
        }
        await queryNowPlaying()
    }

    func pause() async {
        if let bundle = currentMedia?.bundleIdentifier {
            if bundle == "com.apple.Music" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to pause")
            } else if bundle == "com.spotify.client" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to pause")
            } else {
                sendSystemMediaKey(16)
            }
        } else {
            sendSystemMediaKey(16)
        }
        await queryNowPlaying()
    }

    func togglePlayPause() async {
        if let bundle = currentMedia?.bundleIdentifier {
            if bundle == "com.apple.Music" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to playpause")
            } else if bundle == "com.spotify.client" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to playpause")
            } else {
                sendSystemMediaKey(16)
            }
        } else {
            sendSystemMediaKey(16)
        }
        await queryNowPlaying()
    }

    func nextTrack() async {
        if let bundle = currentMedia?.bundleIdentifier {
            if bundle == "com.apple.Music" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to next track")
            } else if bundle == "com.spotify.client" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to next track")
            } else {
                sendSystemMediaKey(19)
            }
        } else {
            sendSystemMediaKey(19)
        }
        await queryNowPlaying()
    }

    func previousTrack() async {
        if let bundle = currentMedia?.bundleIdentifier {
            if bundle == "com.apple.Music" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to previous track")
            } else if bundle == "com.spotify.client" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to previous track")
            } else {
                sendSystemMediaKey(20)
            }
        } else {
            sendSystemMediaKey(20)
        }
        await queryNowPlaying()
    }

    func seek(to seconds: Double) async {
        if let bundle = currentMedia?.bundleIdentifier {
            if bundle == "com.apple.Music" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Music\" to set player position to \(seconds)")
            } else if bundle == "com.spotify.client" {
                _ = try? await CommandRunner.runAppleScript("tell application \"Spotify\" to set player position to \(seconds)")
            }
        }
        await queryNowPlaying()
    }
}
