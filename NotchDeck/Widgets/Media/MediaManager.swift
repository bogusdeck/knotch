// MediaManager.swift
// Observable manager publishing live now-playing state and controls.

import Combine
import Foundation

@MainActor
final class MediaManager: ObservableObject {

    @Published private(set) var currentMedia: MediaItem? = nil

    private let provider: any MediaProvider

    init(provider: (any MediaProvider)? = nil) {
        self.provider = provider ?? CompositeMediaProvider()
        self.provider.startObserving { [weak self] item in
            self?.currentMedia = item
        }
    }

    func stop() {
        provider.stopObserving()
    }

    func play() {
        Task { await provider.play() }
    }

    func pause() {
        Task { await provider.pause() }
    }

    func togglePlayPause() {
        Task { await provider.togglePlayPause() }
    }

    func nextTrack() {
        Task { await provider.nextTrack() }
    }

    func previousTrack() {
        Task { await provider.previousTrack() }
    }

    func seek(to seconds: Double) {
        Task { await provider.seek(to: seconds) }
    }
}
