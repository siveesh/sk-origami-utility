import Foundation

enum ArchiveFormat: String, CaseIterable, Identifiable, Codable {
    case zip
    case sevenZip
    case rar
    case rar5
    case tar
    case tarGzip
    case tarXz
    case tarBzip2
    case gzip
    case jar
    case apk
    case drfx
    case tnef
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zip: "ZIP"
        case .sevenZip: "7-Zip"
        case .rar: "RAR"
        case .rar5: "RAR v5"
        case .tar: "Tar"
        case .tarGzip: "Tar + gz"
        case .tarXz: "Tar + xz"
        case .tarBzip2: "Tar + bz2"
        case .gzip: "Gzip"
        case .jar: "JAR"
        case .apk: "Android APK"
        case .drfx: "DaVinci Resolve FX"
        case .tnef: "Microsoft TNEF"
        case .unknown: "Unknown"
        }
    }

    var preferredExtension: String {
        switch self {
        case .zip: "zip"
        case .sevenZip: "7z"
        case .rar, .rar5: "rar"
        case .tar: "tar"
        case .tarGzip: "tar.gz"
        case .tarXz: "tar.xz"
        case .tarBzip2: "tar.bz2"
        case .gzip: "gz"
        case .jar: "jar"
        case .apk: "apk"
        case .drfx: "drfx"
        case .tnef: "dat"
        case .unknown: "archive"
        }
    }

    var supportsEncryption: Bool {
        switch self {
        case .zip, .sevenZip:
            true
        default:
            false
        }
    }

    var supportsSplitVolumes: Bool {
        switch self {
        case .zip, .sevenZip:
            true
        default:
            false
        }
    }

    var supportsCreationInUI: Bool {
        switch self {
        case .zip, .sevenZip, .tar, .tarGzip, .tarXz, .tarBzip2, .gzip, .jar, .drfx:
            true
        case .apk, .rar, .rar5, .tnef, .unknown:
            false
        }
    }

    static func infer(from url: URL) -> ArchiveFormat {
        let name = url.lastPathComponent.lowercased()
        if name == "winmail.dat" || name.hasSuffix(".tnef") { return .tnef }
        if name.range(of: #"\.part\d+\.rar$"#, options: .regularExpression) != nil { return .rar }
        if name.range(of: #"\.r\d{2,3}$"#, options: .regularExpression) != nil { return .rar }
        if name.range(of: #"\.7z\.\d{3}$"#, options: .regularExpression) != nil { return .sevenZip }
        if name.range(of: #"\.zip\.\d{3}$"#, options: .regularExpression) != nil { return .sevenZip }
        if name.range(of: #"\.z\d{2,3}$"#, options: .regularExpression) != nil { return .zip }
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") { return .tarGzip }
        if name.hasSuffix(".tar.xz") || name.hasSuffix(".txz") { return .tarXz }
        if name.hasSuffix(".tar.bz2") || name.hasSuffix(".tbz2") { return .tarBzip2 }
        if name.hasSuffix(".7z") { return .sevenZip }
        if name.hasSuffix(".rar") { return .rar }
        if name.hasSuffix(".tar") { return .tar }
        if name.hasSuffix(".gz") { return .gzip }
        if name.hasSuffix(".jar") { return .jar }
        if name.hasSuffix(".apk") { return .apk }
        if name.hasSuffix(".drfx") { return .drfx }
        if name.hasSuffix(".zip") { return .zip }
        return .unknown
    }
}
