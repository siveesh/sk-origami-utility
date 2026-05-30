import XCTest
@testable import SKOrigami

final class DiskImageServiceTests: XCTestCase {
    func testSanitizeRemovesExtensionsAndUnsafeCharacters() {
        XCTAssertEqual(DiskImageService.sanitize("../Bad/Name.iso"), "_BadName")
        XCTAssertEqual(DiskImageService.sanitize("  .hidden:dmg?  "), "hiddendmg")
        XCTAssertEqual(DiskImageService.sanitize(""), "output")
    }

    func testDetectFormatDefaultsWindowsInstallerFoldersToISO() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("Installer")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data().write(to: nested.appendingPathComponent("setup.msi"))
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertEqual(DiskImageService.detectFormat(for: root), .iso)
    }

    func testDetectFormatDefaultsOtherFoldersToDMG() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("readme.txt"))
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertEqual(DiskImageService.detectFormat(for: root), .dmg)
    }
}

