// CompositeMediaProvider.swift
// Composite media provider that seamlessly blends MediaRemote (browsers/system) and AppleScript (Spotify/Apple Music).

import Foundation

@MainActor
final class CompositeMediaProvider: MediaProvider {

    enum BackendChoice: String, Sendable {
        case auto
        case mediaRemote = "mediaremote"
        case appleScript = "applescript"
    }

    private let appleScriptProvider: AppleScriptMediaProvider
    private let mediaRemoteProvider: MediaRemoteMediaProvider
    private var activeBackend: BackendChoice

    private(set) var currentMedia: MediaItem? = nil
    private var onChangeCallback: (@MainActor (MediaItem?) -> Void)?

    init(backend: BackendChoice = .auto) {
        self.appleScriptProvider = AppleScriptMediaProvider()
        self.mediaRemoteProvider = MediaRemoteMediaProvider()
        self.activeBackend = backend
    }

    var isAvailable: Bool {
        activeProvider.isAvailable
    }

    private var activeProvider: any MediaProvider {
        switch activeBackend {
        case .appleScript:
            return appleScriptProvider
        case .mediaRemote:
            return mediaRemoteProvider.isAvailable ? mediaRemoteProvider : appleScriptProvider
        case .auto:
            // MediaRemote is preferred if it has media playing
            if mediaRemoteProvider.isAvailable, let remoteMedia = mediaRemoteProvider.currentMedia, remoteMedia.isPlaying {
                return mediaRemoteProvider
            }
            // AppleScript if playing
            if let scriptMedia = appleScriptProvider.currentMedia, scriptMedia.isPlaying {
                return appleScriptProvider
            }
            // If neither is playing, pick whichever has current media
            if mediaRemoteProvider.isAvailable, mediaRemoteProvider.currentMedia != nil {
                return mediaRemoteProvider
            }
            if appleScriptProvider.currentMedia != nil {
                return appleScriptProvider
            }
            return mediaRemoteProvider.isAvailable ? mediaRemoteProvider : appleScriptProvider
        }
    }

    func startObserving(onChange: @escaping @MainActor (MediaItem?) -> Void) {
        self.onChangeCallback = onChange

        mediaRemoteProvider.startObserving { [weak self] _ in
            self?.updateCurrentMedia()
        }

        appleScriptProvider.startObserving { [weak self] _ in
            self?.updateCurrentMedia()
        }
    }

    func stopObserving() {
        mediaRemoteProvider.stopObserving()
        appleScriptProvider.stopObserving()
        onChangeCallback = nil
    }

    private func updateCurrentMedia() {
        let item = activeProvider.currentMedia
        if item != currentMedia {
            currentMedia = item
            onChangeCallback?(item)
        }
    }

    func play() async {
        await activeProvider.play()
    }

    func pause() async {
        await activeProvider.pause()
    }

    func togglePlayPause() async {
        await activeProvider.togglePlayPause()
    }

    func nextTrack() async {
        await activeProvider.nextTrack()
    }

    func previousTrack() async {
        await activeProvider.previousTrack()
    }

    func seek(to seconds: Double) async {
        await activeProvider.seek(to: seconds)
    }
}
