import Foundation
import CryptoKit
import PhononTTS

/// One resumable file download. Uses a download task so cancellation can keep resume data.
final class ResumableDownload: NSObject, URLSessionDownloadDelegate {
    private let file: RemoteFile
    private let destination: URL
    private let resumeURL: URL
    private let onProgress: @Sendable (Int64, Int64) -> Void
    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private var moved = false

    init(
        file: RemoteFile,
        destination: URL,
        resumeURL: URL,
        onProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) {
        self.file = file
        self.destination = destination
        self.resumeURL = resumeURL
        self.onProgress = onProgress
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func start() async throws -> URL {
        let resumeData = try? Data(contentsOf: resumeURL)
        let task: URLSessionDownloadTask
        if let resumeData, !resumeData.isEmpty {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: file.url)
        }
        self.task = task
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            task.resume()
        }
    }

    func cancel() {
        task?.cancel(byProducingResumeData: { [weak self] data in
            guard let self else { return }
            if let data { try? data.write(to: self.resumeURL) }
        })
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : file.bytes
        onProgress(totalBytesWritten, expected)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: destination)
            try fm.moveItem(at: location, to: destination)
            moved = true
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session.finishTasksAndInvalidate() }
        if let error {
            if let resume = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                try? resume.write(to: resumeURL)
            }
            if (error as NSError).code == NSURLErrorCancelled {
                finish(.failure(CancellationError()))
            } else {
                finish(.failure(error))
            }
            return
        }
        if moved {
            try? FileManager.default.removeItem(at: resumeURL)
            finish(.success(destination))
        } else {
            finish(.failure(URLError(.cannotWriteToFile)))
        }
    }
}

enum ModelStoreError: LocalizedError {
    case notEnoughSpace
    case badChecksum(String)
    case missingFiles
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .notEnoughSpace: "Not enough free disk space for this download."
        case .badChecksum(let name): "\(name) did not match its checksum. Deleted the file."
        case .missingFiles: "The downloaded package is incomplete."
        case .extractionFailed: "Could not unpack the voice model."
        }
    }
}

@MainActor
final class ModelStore: ObservableObject {
    enum Status: Equatable {
        case absent
        case downloading(progress: Double, received: Int64, total: Int64)
        case verifying
        case installing
        case ready
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .downloading, .verifying, .installing: true
            default: false
            }
        }

        var fraction: Double {
            if case .downloading(let p, _, _) = self { return p }
            if case .verifying = self { return 0.99 }
            if case .installing = self { return 0.99 }
            return 0
        }
    }

    @Published private(set) var status: [ModelKind: Status] = [:]
    private var downloads: [ModelKind: ResumableDownload] = [:]
    private var jobs: [ModelKind: Task<Void, Never>] = [:]

    init() {
        AppPaths.ensureDirectories()
        refresh()
    }

    var voiceReady: Bool { isInstalled(.voice) }
    var brainReady: Bool { isInstalled(.brain) }
    var coreReady: Bool { voiceReady && brainReady }

    func isInstalled(_ kind: ModelKind) -> Bool {
        switch kind {
        case .voice:
            return PhononModels.isInstalled()
        case .brain:
            return ModelCatalog.package(kind).files.allSatisfy { file in
                fileMatches(ModelCatalog.destination(for: file), file)
            }
        }
    }

    func status(of kind: ModelKind) -> Status {
        status[kind] ?? (isInstalled(kind) ? .ready : .absent)
    }

    func refresh() {
        for kind in ModelKind.allCases where status[kind]?.isBusy != true {
            status[kind] = isInstalled(kind) ? .ready : (status[kind] ?? .absent)
        }
    }

    func download(_ kind: ModelKind) {
        guard jobs[kind] == nil else { return }
        jobs[kind] = Task { [weak self] in
            await self?.run(kind)
        }
    }

    func cancel(_ kind: ModelKind) {
        downloads[kind]?.cancel()
        jobs[kind]?.cancel()
    }

    func delete(_ kind: ModelKind) {
        NotificationCenter.default.post(name: .modelWillDelete, object: kind)
        cancel(kind)
        let fm = FileManager.default
        switch kind {
        case .voice:
            try? fm.removeItem(at: PhononModels.defaultDirectory)
            try? fm.removeItem(at: AppPaths.downloads.appendingPathComponent(ModelCatalog.voice.files[0].fileName))
            try? fm.removeItem(at: AppPaths.downloads.appendingPathComponent("voice-extract"))
        case .brain:
            for file in ModelCatalog.package(kind).files {
                try? fm.removeItem(at: ModelCatalog.destination(for: file))
            }
        }
        status[kind] = .absent
    }

    func bytesOnDisk(_ kind: ModelKind) -> Int64 {
        switch kind {
        case .voice:
            return folderSize(PhononModels.defaultDirectory)
        case .brain:
            return ModelCatalog.package(kind).files.reduce(0) { sum, file in
                sum + AppPaths.size(of: ModelCatalog.destination(for: file))
            }
        }
    }

    // MARK: - Work

    private func run(_ kind: ModelKind) async {
        let package = ModelCatalog.package(kind)
        defer {
            jobs[kind] = nil
            downloads[kind] = nil
        }
        do {
            guard AppPaths.freeBytes() > package.totalBytes + 300_000_000 else {
                throw ModelStoreError.notEnoughSpace
            }
            AppPaths.ensureDirectories()

            if kind == .voice {
                try await installVoice(package)
            } else {
                try await fetchFiles(package)
            }
            status[kind] = .ready
        } catch is CancellationError {
            status[kind] = isInstalled(kind) ? .ready : .absent
        } catch {
            status[kind] = .failed(error.localizedDescription)
        }
    }

    private func fetchFiles(_ package: ModelPackage) async throws {
        for file in package.files {
            guard !fileMatches(ModelCatalog.destination(for: file), file) else { continue }
            status[package.id] = .downloading(progress: 0, received: 0, total: file.bytes)
            let download = ResumableDownload(
                file: file,
                destination: ModelCatalog.destination(for: file),
                resumeURL: AppPaths.downloads.appendingPathComponent(file.fileName + ".resume")
            ) { [weak self] received, total in
                Task { @MainActor in
                    guard let self, self.jobs[package.id] != nil else { return }
                    let fraction = total > 0 ? min(1, Double(received) / Double(total)) : 0
                    self.status[package.id] = .downloading(progress: fraction, received: received, total: total)
                }
            }
            downloads[package.id] = download
            _ = try await download.start()
            downloads[package.id] = nil

            status[package.id] = .verifying
            let digest = try sha256(ModelCatalog.destination(for: file))
            guard digest == file.sha256 else {
                try? FileManager.default.removeItem(at: ModelCatalog.destination(for: file))
                throw ModelStoreError.badChecksum(file.fileName)
            }
        }
    }

    private func installVoice(_ package: ModelPackage) async throws {
        let zip = package.files[0]
        let archive = AppPaths.downloads.appendingPathComponent(zip.fileName)

        if !fileMatches(archive, zip) {
            status[.voice] = .downloading(progress: 0, received: 0, total: zip.bytes)
            let download = ResumableDownload(file: zip, destination: archive, resumeURL: AppPaths.downloads.appendingPathComponent(zip.fileName + ".resume")) { [weak self] received, total in
                Task { @MainActor in
                    guard let self, self.jobs[.voice] != nil else { return }
                    let fraction = total > 0 ? min(1, Double(received) / Double(total)) : 0
                    self.status[.voice] = .downloading(progress: fraction, received: received, total: total)
                }
            }
            downloads[.voice] = download
            _ = try await download.start()
            downloads[.voice] = nil
        }

        status[.voice] = .verifying
        guard try sha256(archive) == zip.sha256 else {
            try? FileManager.default.removeItem(at: archive)
            throw ModelStoreError.badChecksum(zip.fileName)
        }

        status[.voice] = .installing
        let extract = AppPaths.downloads.appendingPathComponent("voice-extract", isDirectory: true)
        try? FileManager.default.removeItem(at: extract)
        try await Self.unzip(archive, to: extract)

        guard let bundle = Self.findBundle(in: extract) else {
            throw ModelStoreError.extractionFailed
        }
        try PhononModels.install(bundled: bundle)

        try? FileManager.default.removeItem(at: extract)
        try? FileManager.default.removeItem(at: archive)
        try? FileManager.default.removeItem(at: AppPaths.downloads.appendingPathComponent(zip.fileName + ".resume"))
    }

    // MARK: - Helpers

    private func fileMatches(_ url: URL, _ file: RemoteFile) -> Bool {
        AppPaths.size(of: url) == file.bytes
    }

    private func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 8 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func folderSize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let item as URL in enumerator {
            total += AppPaths.size(of: item)
        }
        return total
    }

    private static func unzip(_ archive: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    process.arguments = ["-xk", archive.path, destination.path]
                    try process.run()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        throw ModelStoreError.extractionFailed
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func findBundle(in folder: URL) -> URL? {
        if FileManager.default.fileExists(atPath: folder.appendingPathComponent("bundle.json").path) {
            return folder
        }
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for item in items where FileManager.default.fileExists(atPath: item.appendingPathComponent("bundle.json").path) {
            return item
        }
        return nil
    }
}
