import Foundation

enum DropBehavior {
    case openArchives
    case createArchive
    case createDiskImage
    case extractArchive

    var statusMessage: String {
        switch self {
        case .openArchives:
            "Drop archive files to open them."
        case .createArchive:
            "Drop files or folders to create an archive."
        case .createDiskImage:
            "Drop folders to create DMG or ISO disk images."
        case .extractArchive:
            "Drop an archive file to extract it."
        }
    }
}

