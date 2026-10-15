// ConfigWatcher.swift
// NotchDeck
//
// Watches the parent directory of config.toml for filesystem changes using
// DispatchSource.makeFileSystemObjectSource with a `.write` event mask.
// Watching the *directory* (rather than the file itself) is more reliable
// because many editors write a temp file and rename it into place, which
// would silently miss events on a bare file-descriptor watch.
//
// Debounce: the onChange callback fires 300 ms after the last observed event.

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.notchdeck.app", category: "ConfigWatcher")

// MARK: - ConfigWatcher

/// Monitors the parent directory of a configuration file for changes and
/// invokes `onChange` (on the main actor) whenever the directory is written to.
@MainActor
final class ConfigWatcher {

    // MARK: - Public

    let url: URL

    // MARK: - Private

    private let onChange: @MainActor () -> Void
    private let watchQueue: DispatchQueue
    private var source: (any DispatchSourceFileSystemObject)?
    private var directoryFD: Int32 = -1
    private var pendingWork: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.3

    // MARK: - Init / Deinit

    init(url: URL, onChange: @MainActor @escaping () -> Void) {
        self.url      = url
        self.onChange = onChange
        self.watchQueue = DispatchQueue(
            label: "com.notchdeck.configwatcher",
            qos: .utility,
            attributes: [],
            autoreleaseFrequency: .workItem
        )
        logger.debug("ConfigWatcher initialised for \(url.path, privacy: .public)")
    }

    deinit {
        source?.cancel()
        source = nil
        logger.debug("ConfigWatcher deallocated")
    }

    // MARK: - Public API

    func start() {
        guard source == nil else {
            logger.debug("ConfigWatcher already running — ignoring start()")
            return
        }

        let directoryURL = url.deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            logger.warning("Config directory does not exist yet: \(directoryURL.path, privacy: .public)")
            return
        }

        // O_EVTONLY: watch without blocking unmount
        let fd = open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.error("Failed to open directory fd (errno \(errno))")
            return
        }
        directoryFD = fd

        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: watchQueue
        )

        let debounce = self.debounceInterval
        let box = PendingWorkBox()

        newSource.setEventHandler { [weak self] in
            box.item?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                logger.info("Config directory changed — reloading")
                Task { @MainActor [weak self] in self?.onChange() }
            }
            box.item = work
            DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
        }

        newSource.setCancelHandler {
            close(fd)
            logger.debug("ConfigWatcher fd closed")
        }

        source = newSource
        newSource.resume()
        logger.info("ConfigWatcher watching \(directoryURL.path, privacy: .public)")
    }

    func stop() {
        source?.cancel()
        source = nil
        pendingWork?.cancel()
        pendingWork = nil
        logger.info("ConfigWatcher stopped")
    }
}

// MARK: - PendingWorkBox

/// Reference-type wrapper so the nonisolated DispatchSource event-handler
/// can mutate a `DispatchWorkItem?` without capturing @MainActor self.
private final class PendingWorkBox: @unchecked Sendable {
    var item: DispatchWorkItem?
}
