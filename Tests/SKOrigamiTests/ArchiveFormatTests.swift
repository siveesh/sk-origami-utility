import XCTest
@testable import SKOrigami

final class ArchiveFormatTests: XCTestCase {
    func testInfersCommonCompoundExtensions() {
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/sample.tar.gz")), .tarGzip)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/sample.tar.xz")), .tarXz)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/sample.drfx")), .drfx)
        XCTAssertEqual(ArchiveFormat.infer(from: URL(fileURLWithPath: "/tmp/winmail.dat")), .tnef)
    }
}
