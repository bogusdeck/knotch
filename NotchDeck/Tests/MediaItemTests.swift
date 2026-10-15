// MediaItemTests.swift
// Unit tests for MediaItem progress calculation, time formatting, and provider interfaces.

import XCTest
@testable import NotchDeck

@MainActor
final class MediaItemTests: XCTestCase {

    func testMediaItemTimeFormatting() {
        let item = MediaItem(
            title: "Song Title",
            artist: "Artist Name",
            album: "Album Name",
            duration: 215.0, // 3:35
            elapsedTime: 65.0, // 1:05
            isPlaying: true,
            bundleIdentifier: "com.spotify.client",
            artworkData: nil
        )

        XCTAssertEqual(item.formattedElapsed, "1:05")
        XCTAssertEqual(item.formattedDuration, "3:35")
        XCTAssertEqual(item.progress, 65.0 / 215.0, accuracy: 0.001)
    }

    func testMediaItemProgressClamping() {
        let itemZero = MediaItem(
            title: "Test",
            artist: "Test",
            album: "",
            duration: 0.0,
            elapsedTime: 0.0,
            isPlaying: false,
            bundleIdentifier: nil,
            artworkData: nil
        )
        XCTAssertEqual(itemZero.progress, 0.0)

        let itemOver = MediaItem(
            title: "Test",
            artist: "Test",
            album: "",
            duration: 100.0,
            elapsedTime: 120.0,
            isPlaying: false,
            bundleIdentifier: nil,
            artworkData: nil
        )
        XCTAssertEqual(itemOver.progress, 1.0)
    }
}
