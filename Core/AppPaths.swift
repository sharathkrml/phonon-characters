import Foundation

enum AppPaths {
    static var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhononCharacters", isDirectory: true)
    }

    static var models: URL { support.appendingPathComponent("Models", isDirectory: true) }
    static var downloads: URL { support.appendingPathComponent("Downloads", isDirectory: true) }
    static var logs: URL { support.appendingPathComponent("Logs", isDirectory: true) }

    static func ensureDirectories() {
        for dir in [support, models, downloads, logs] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func freeBytes() -> Int64 {
        (try? support.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))
            .flatMap(\.volumeAvailableCapacityForImportantUsage) ?? 0
    }

    static func size(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return 0 }
        return Int64(size)
    }

    static func megabytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
