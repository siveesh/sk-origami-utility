import CoreServices
import Foundation
import UniformTypeIdentifiers

struct FileAssociationResult {
    var updated: Int
    var failed: [(String, String)]

    var message: String {
        if failed.isEmpty {
            return "Set SK Origami as the default app for \(updated) archive type\(updated == 1 ? "" : "s")."
        }
        return "Updated \(updated) type\(updated == 1 ? "" : "s"); \(failed.count) failed."
    }
}

final class FileAssociationService {
    private let extensions = [
        "zip", "7z", "rar", "tar", "gz", "tgz", "xz", "txz", "bz2", "tbz2", "jar", "apk", "drfx", "dat", "tnef"
    ]

    func makeSKOrigamiDefaultArchiveApp() -> FileAssociationResult {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.skorigami.app"
        var updated = 0
        var failed: [(String, String)] = []

        for fileExtension in extensions {
            guard let contentType = UTType(filenameExtension: fileExtension)?.identifier else {
                failed.append((fileExtension, "No UTI found"))
                continue
            }

            let status = LSSetDefaultRoleHandlerForContentType(
                contentType as CFString,
                .viewer,
                bundleIdentifier as CFString
            )

            if status == noErr {
                updated += 1
            } else {
                failed.append((fileExtension, "LaunchServices error \(status)"))
            }
        }

        return FileAssociationResult(updated: updated, failed: failed)
    }
}
