import XCTest
@testable import SKOrigami

final class ArchiveFormatTests: XCTestCase {
    func testInfersCommonCompoundExtensions() {
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/sample.tar.gz")), .tarGzip)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/sample.tar.xz")), .tarXz)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/sample.drfx")), .drfx)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/winmail.dat")), .tnef)
    }

    func testInfersMultipartArchiveSegments() {
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/movie.7z.001")), .sevenZip)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/movie.zip.001")), .sevenZip)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/movie.z01")), .zip)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/movie.part01.rar")), .rar)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/movie.r00")), .rar)
    }

    func testFindsSevenZipMultipartFamily() throws {
        let folder = try makeTemporaryFolder()
        let firstPart = folder.appendingPathComponent("project.7z.001")
        try Data().write(to: firstPart)
        try Data().write(to: folder.appendingPathComponent("project.7z.002"))
        try Data().write(to: folder.appendingPathComponent("project.7z.003"))
        try Data().write(to: folder.appendingPathComponent("other.7z.001"))

        let names = ArchiveService().archiveFamilyURLs(containing: firstPart).map(\.lastPathComponent)

        XCTAssertEqual(names, ["project.7z.001", "project.7z.002", "project.7z.003"])
    }

    func testFindsZipMultipartFamilyFromFinalZip() throws {
        let folder = try makeTemporaryFolder()
        let finalPart = folder.appendingPathComponent("backup.zip")
        try Data().write(to: folder.appendingPathComponent("backup.z01"))
        try Data().write(to: folder.appendingPathComponent("backup.z02"))
        try Data().write(to: finalPart)

        let names = ArchiveService().archiveFamilyURLs(containing: finalPart).map(\.lastPathComponent)

        XCTAssertEqual(names, ["backup.z01", "backup.z02", "backup.zip"])
    }

    func testChoosesFinalZipAsPrimaryForSplitZipFamily() throws {
        let folder = try makeTemporaryFolder()
        let firstPart = folder.appendingPathComponent("backup.z01")
        let finalPart = folder.appendingPathComponent("backup.zip")
        try Data().write(to: firstPart)
        try Data().write(to: folder.appendingPathComponent("backup.z02"))
        try Data().write(to: finalPart)

        let primary = ArchiveService().primaryArchiveURL(containing: firstPart)

        XCTAssertEqual(primary.lastPathComponent, "backup.zip")
    }

    func testFindsRarPartFamily() throws {
        let folder = try makeTemporaryFolder()
        let firstPart = folder.appendingPathComponent("backup.part1.rar")
        try Data().write(to: firstPart)
        try Data().write(to: folder.appendingPathComponent("backup.part2.rar"))
        try Data().write(to: folder.appendingPathComponent("backup.part3.rar"))

        let names = ArchiveService().archiveFamilyURLs(containing: firstPart).map(\.lastPathComponent)

        XCTAssertEqual(names, ["backup.part1.rar", "backup.part2.rar", "backup.part3.rar"])
    }

    func testChoosesRarAsPrimaryForOldStyleRarFamily() throws {
        let folder = try makeTemporaryFolder()
        let firstPart = folder.appendingPathComponent("backup.r00")
        let mainPart = folder.appendingPathComponent("backup.rar")
        try Data().write(to: firstPart)
        try Data().write(to: folder.appendingPathComponent("backup.r01"))
        try Data().write(to: mainPart)

        let primary = ArchiveService().primaryArchiveURL(containing: firstPart)

        XCTAssertEqual(primary.lastPathComponent, "backup.rar")
    }

    private func makeTemporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: folder)
        }
        return folder
    }
}
