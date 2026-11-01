import Foundation

/// Append-only diagnostic log. Small, local, and only written at state transitions.
enum DebugLog {
    private static let queue = DispatchQueue(label: "phonon.log")
    private static let url: URL = {
        AppPaths.ensureDirectories()
        return AppPaths.logs.appendingPathComponent("app.log")
    }()

    static func write(_ message: String) {
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(message)\n"
        queue.async {
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                fm.createFile(atPath: url.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            }
        }
    }
}
