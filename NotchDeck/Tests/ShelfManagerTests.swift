// ShelfManagerTests.swift
// Unit tests for ShelfManager, ShelfItem, and copy-on-drop behavior.

import XCTest
@testable import NotchDeck

@MainActor
final class ShelfManagerTests: XCTestCase {

    var tempDir: URL!
    var shelfManager: ShelfManager!
    var sampleFile: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotchDeckShelfTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        shelfManager = ShelfManager(shelfDirectory: tempDir)

        sampleFile = tempDir.appendingPathComponent("sample.txt")
        try? "Sample file content".write(to: sampleFile, atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testAddReferenceItem() {
        let item = shelfManager.addItem(from: sampleFile, copyOnDrop: false)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.name, "sample.txt")
        XCTAssertFalse(item?.isFolder ?? true)
        XCTAssertFalse(item?.isCopied ?? true)
        XCTAssertEqual(shelfManager.items.count, 1)
    }

    func testAddWithCopyOnDrop() {
        let item = shelfManager.addItem(from: sampleFile, copyOnDrop: true)
        XCTAssertNotNil(item)
        XCTAssertTrue(item?.isCopied ?? false)
        XCTAssertEqual(shelfManager.items.count, 1)

        // Target file should exist in files directory
        let copiedFile = shelfManager.filesDirectory.appendingPathComponent("sample.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedFile.path))
    }

    func testRemoveItemCleansUpCopiedFile() {
        guard let item = shelfManager.addItem(from: sampleFile, copyOnDrop: true) else {
            XCTFail("Failed to add copied item")
            return
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: item.url.path))
        shelfManager.removeItem(item)

        XCTAssertEqual(shelfManager.items.count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.url.path))
    }

    func testRemoveReferenceItemPreservesOriginalFile() {
        guard let item = shelfManager.addItem(from: sampleFile, copyOnDrop: false) else {
            XCTFail("Failed to add reference item")
            return
        }

        shelfManager.removeItem(item)
        XCTAssertEqual(shelfManager.items.count, 0)
        // Original sampleFile must still exist!
        XCTAssertTrue(FileManager.default.fileExists(atPath: sampleFile.path))
    }

    func testAddFolderItem() {
        let sampleFolder = tempDir.appendingPathComponent("testFolder")
        try? FileManager.default.createDirectory(at: sampleFolder, withIntermediateDirectories: true)

        let item = shelfManager.addItem(from: sampleFolder, copyOnDrop: false)
        XCTAssertNotNil(item)
        XCTAssertTrue(item?.isFolder ?? false)
    }
}
