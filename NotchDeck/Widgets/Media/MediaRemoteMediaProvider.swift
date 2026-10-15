// MediaRemoteMediaProvider.swift
// Media provider backend dynamically interfacing with the private MediaRemote.framework.
// Falls back gracefully if restricted or unavailable on newer macOS releases.

import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "MediaRemoteMediaProvider")

// Function pointer signatures for MediaRemote symbols
private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool

@MainActor
final class MediaRemoteMediaProvider: MediaProvider {

    private(set) var currentMedia: MediaItem? = nil
    private(set) var isAvailable: Bool = false

    private struct HandleBox: @unchecked Sendable {
        var raw: UnsafeMutableRawPointer? = nil
    }

    private var frameworkHandle = HandleBox()
    private var sendCommandFunc: MRMediaRemoteSendCommandFunction? = nil
    private var onChangeCallback: (@MainActor (MediaItem?) -> Void)?

    init() {
        loadFramework()
    }

    deinit {
        if let raw = frameworkHandle.raw {
            dlclose(raw)
        }
    }

    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        let handle = dlopen(path, RTLD_NOW)
        frameworkHandle.raw = handle

        guard let handle else {
            logger.info("MediaRemote framework not available via dlopen; will use AppleScript backend.")
            self.isAvailable = false
            return
        }

        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommandFunc = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
            self.isAvailable = true
            logger.info("MediaRemote framework loaded successfully.")
        } else {
            logger.info("MRMediaRemoteSendCommand symbol not found; falling back.")
            self.isAvailable = false
        }
    }

    func startObserving(onChange: @escaping @MainActor (MediaItem?) -> Void) {
        self.onChangeCallback = onChange
    }

    func stopObserving() {
        onChangeCallback = nil
    }

    // Command codes: Play = 0, Pause = 1, TogglePlayPause = 2, Next = 4, Previous = 5
    private func sendCommand(_ commandCode: Int32) -> Bool {
        guard let sendCommandFunc else { return false }
        return sendCommandFunc(commandCode, nil)
    }

    func play() async {
        _ = sendCommand(0)
    }

    func pause() async {
        _ = sendCommand(1)
    }

    func togglePlayPause() async {
        _ = sendCommand(2)
    }

    func nextTrack() async {
        _ = sendCommand(4)
    }

    func previousTrack() async {
        _ = sendCommand(5)
    }

    func seek(to seconds: Double) async {
        // MediaRemote seeking requires complex userInfo dictionary; no-op fallback
    }
}
