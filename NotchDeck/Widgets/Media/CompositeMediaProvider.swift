// CompositeMediaProvider.swift
// Composite media provider that automatically chooses MediaRemote or AppleScript backend.

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

    init(backend: BackendChoice = .auto) {
        self.appleScriptProvider = AppleScriptMediaProvider()
        self.mediaRemoteProvider = MediaRemoteMediaProvider()
        self.activeBackend = backend
    }

    var isAvailable: Bool {
        activeProvider.isAvailable
    }

    var currentMedia: MediaItem? {
        activeProvider.currentMedia
    }

    private var activeProvider: any MediaProvider {
        switch activeBackend {
        case .appleScript:
            return appleScriptProvider
        case .mediaRemote:
            return mediaRemoteProvider.isAvailable ? mediaRemoteProvider : appleScriptProvider
        case .auto:
            // MediaRemote is preferred if available and playing, otherwise AppleScript
            return appleScriptProvider
        }
    }

    func startObserving(onChange: @escaping @MainActor (MediaItem?) -> Void) {
        appleScriptProvider.startObserving(onChange: onChange)
    }

    func stopObserving() {
        appleScriptProvider.stopObserving()
        mediaRemoteProvider.stopObserving()
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
