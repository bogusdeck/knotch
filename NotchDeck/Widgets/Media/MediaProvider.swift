// MediaProvider.swift
// Protocol for media player backends.

import Foundation

@MainActor
protocol MediaProvider: AnyObject {
    var currentMedia: MediaItem? { get }
    var isAvailable: Bool { get }

    func play() async
    func pause() async
    func togglePlayPause() async
    func nextTrack() async
    func previousTrack() async
    func seek(to seconds: Double) async

    func startObserving(onChange: @escaping @MainActor (MediaItem?) -> Void)
    func stopObserving()
}
