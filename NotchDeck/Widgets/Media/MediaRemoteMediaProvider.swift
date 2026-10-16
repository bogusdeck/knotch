// MediaRemoteMediaProvider.swift
// Media provider backend dynamically interfacing with the private MediaRemote.framework.
// Supports macOS system Now Playing (Zen Browser, Safari, Chrome, YouTube, Spotify, Music, etc.)

import AppKit
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "MediaRemoteMediaProvider")

// Function pointer signatures for MediaRemote symbols
private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool
private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary?) -> Void) -> Void
private typealias MRMediaRemoteGetNowPlayingApplicationPIDFunction = @convention(c) (DispatchQueue, @escaping (pid_t) -> Void) -> Void
private typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunction = @convention(c) (DispatchQueue) -> Void
private typealias MRMediaRemoteUnregisterForNowPlayingNotificationsFunction = @convention(c) () -> Void
private typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void

@MainActor
final class MediaRemoteMediaProvider: MediaProvider {

    private(set) var currentMedia: MediaItem? = nil
    private(set) var isAvailable: Bool = false

    private struct HandleBox: @unchecked Sendable {
        var raw: UnsafeMutableRawPointer? = nil
    }

    private var frameworkHandle = HandleBox()
    private var sendCommandFunc: MRMediaRemoteSendCommandFunction?
    private var getNowPlayingInfoFunc: MRMediaRemoteGetNowPlayingInfoFunction?
    private var getNowPlayingPIDFunc: MRMediaRemoteGetNowPlayingApplicationPIDFunction?
    private var registerNotifsFunc: MRMediaRemoteRegisterForNowPlayingNotificationsFunction?
    private var unregisterNotifsFunc: MRMediaRemoteUnregisterForNowPlayingNotificationsFunction?
    private var isPlayingFunc: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction?

    private var onChangeCallback: (@MainActor (MediaItem?) -> Void)?
    private var pollTimer: Task<Void, Never>?
    private var notificationObserver: Any?

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
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getNowPlayingInfoFunc = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID") {
            getNowPlayingPIDFunc = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingApplicationPIDFunction.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerNotifsFunc = unsafeBitCast(sym, to: MRMediaRemoteRegisterForNowPlayingNotificationsFunction.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteUnregisterForNowPlayingNotifications") {
            unregisterNotifsFunc = unsafeBitCast(sym, to: MRMediaRemoteUnregisterForNowPlayingNotificationsFunction.self)
        }
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            isPlayingFunc = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction.self)
        }

        if sendCommandFunc != nil && getNowPlayingInfoFunc != nil {
            self.isAvailable = true
            logger.info("MediaRemote framework loaded successfully with Now Playing observation.")
        } else {
            self.isAvailable = false
        }
    }

    // MARK: - Observation

    func startObserving(onChange: @escaping @MainActor (MediaItem?) -> Void) {
        self.onChangeCallback = onChange

        guard isAvailable else { return }

        registerNotifsFunc?(DispatchQueue.main)

        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.queryNowPlaying()
            }
        }

        pollTimer?.cancel()
        pollTimer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.queryNowPlaying()
                let isPlaying = self?.currentMedia?.isPlaying ?? false
                let delay = isPlaying ? 1_000_000_000 : 2_000_000_000
                try? await Task.sleep(nanoseconds: UInt64(delay))
            }
        }
    }

    func stopObserving() {
        pollTimer?.cancel()
        pollTimer = nil

        if let obs = notificationObserver {
            NotificationCenter.default.removeObserver(obs)
            notificationObserver = nil
        }

        unregisterNotifsFunc?()
        onChangeCallback = nil
    }

    private struct RawNowPlayingData: Sendable {
        let title: String
        let artist: String
        let album: String
        let duration: Double
        let elapsedTime: Double
        let rate: Double
        let artworkData: Data?
    }

    // MARK: - Query

    func queryNowPlaying() async {
        guard let getInfo = getNowPlayingInfoFunc else { return }

        let rawData: RawNowPlayingData? = await withCheckedContinuation { continuation in
            getInfo(DispatchQueue.global()) { info in
                guard let dict = info as? [String: Any] else {
                    continuation.resume(returning: nil)
                    return
                }
                let title = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !title.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let artist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
                let album = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? ""
                let duration = (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0.0
                let elapsedTime = (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0.0
                let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0.0
                let artworkData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data

                continuation.resume(returning: RawNowPlayingData(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    elapsedTime: elapsedTime,
                    rate: rate,
                    artworkData: artworkData
                ))
            }
        }

        guard let raw = rawData else {
            if currentMedia != nil {
                currentMedia = nil
                onChangeCallback?(nil)
            }
            return
        }

        var bundleId: String? = nil
        if let getPID = getNowPlayingPIDFunc {
            let pid: pid_t = await withCheckedContinuation { continuation in
                getPID(DispatchQueue.global()) { pid in
                    continuation.resume(returning: pid)
                }
            }
            if pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                bundleId = app.bundleIdentifier
            }
        }

        let isPlaying = raw.rate > 0.0
        let newItem = MediaItem(
            title: raw.title,
            artist: raw.artist,
            album: raw.album,
            duration: raw.duration,
            elapsedTime: raw.elapsedTime,
            isPlaying: isPlaying,
            bundleIdentifier: bundleId,
            artworkData: raw.artworkData
        )

        if newItem != currentMedia {
            currentMedia = newItem
            onChangeCallback?(newItem)
        }
    }

    // MARK: - Controls

    private func sendCommand(_ commandCode: Int32) -> Bool {
        guard let sendCommandFunc else { return false }
        return sendCommandFunc(commandCode, nil)
    }

    func play() async {
        _ = sendCommand(0)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await queryNowPlaying()
    }

    func pause() async {
        _ = sendCommand(1)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await queryNowPlaying()
    }

    func togglePlayPause() async {
        _ = sendCommand(2)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await queryNowPlaying()
    }

    func nextTrack() async {
        _ = sendCommand(4)
        try? await Task.sleep(nanoseconds: 500_000_000)
        await queryNowPlaying()
    }

    func previousTrack() async {
        _ = sendCommand(5)
        try? await Task.sleep(nanoseconds: 500_000_000)
        await queryNowPlaying()
    }

    func seek(to seconds: Double) async {
        // MediaRemote seeking requires complex userInfo dictionary; no-op fallback
    }
}
