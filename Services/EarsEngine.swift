import Foundation

/// The ears: Phonon-2.5 English by Fermion Research, an MLX speech model that streams partial
/// transcripts over a WebSocket. It runs as a small sidecar because the engine is Python/MLX;
/// the runtime and the 158 MB model are fetched once, on demand.
@MainActor
final class EarsEngine: ObservableObject {
    enum State: Equatable {
        case absent
        case installing(String)
        case readyEngine
        case starting
        case ready
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .installing, .starting: true
            default: false
            }
        }
    }

    static let modelAlias = "phonon-2.5-en"
    static let modelRepo = "FermionResearch/Phonon-2.5-English"
    static let engineVersion = "0.2.15"

    @Published private(set) var state: State = .absent
    @Published private(set) var port = 0
    @Published private(set) var detail: String = ""

    private var process: Process?
    private var installTask: Task<Void, Never>?
    private var startup: Task<Void, Error>?

    /// Keeps live engines reachable so app termination can shut them down.
    private static var live: [EarsEngine] = []

    private var root: URL { AppPaths.support.appendingPathComponent("Ears", isDirectory: true) }
    private var venv: URL { root.appendingPathComponent("venv", isDirectory: true) }
    private var fermion: URL { venv.appendingPathComponent("bin/fermion") }

    var engineInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: fermion.path)
    }

    var isReady: Bool { state == .ready }

    init() {
        refresh()
        Self.live.append(self)
    }

    static func stopAll() {
        for engine in live { engine.stop() }
    }

    func refresh() {
        if engineInstalled {
            if process == nil { state = .readyEngine }
        } else if !state.isBusy {
            state = .absent
        }
    }

    // MARK: - Install

    func install() {
        guard installTask == nil else { return }
        installTask = Task { [weak self] in
            await self?.runInstall()
        }
    }

    private func runInstall() async {
        defer { installTask = nil }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            AppPaths.ensureDirectories()
            let log = try logHandle(named: "ears-engine.log")

            state = .installing("Preparing the engine runtime…")
            let uv = try await uvBinary()

            if !engineInstalled {
                state = .installing("Creating a Python 3.13 environment…")
                try await run([uv.path, "venv", "--python", "3.13", venv.path], log: log, label: "uv venv")

                state = .installing("Installing the Phonon-2.5 engine (about 150 MB)…")
                try await run(
                    [uv.path, "pip", "install", "--python", venv.appendingPathComponent("bin/python").path,
                     "fermion-research[mlx]==\(Self.engineVersion)"],
                    log: log, label: "uv pip install", timeout: 1800
                )

                state = .installing("Trimming unused packages…")
                // torch is an unconditional dependency of the package but unused on the MLX path.
                _ = try? await run(
                    [uv.path, "pip", "uninstall", "--python", venv.appendingPathComponent("bin/python").path,
                     "torch", "sympy", "networkx"],
                    log: log, label: "uv pip uninstall", timeout: 300
                )
            }

            guard engineInstalled else { throw EarsError.installFailed }
            DebugLog.write("ears engine installed")
            state = .readyEngine
            detail = "Phonon-2.5 English · \(Self.engineVersion)"
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Server

    func start() async throws {
        if state == .ready, process != nil { return }
        if let startup {
            try await startup.value
            return
        }
        let task = Task { try await self.launchServer() }
        startup = task
        defer { startup = nil }
        try await task.value
    }

    private func launchServer() async throws {
        guard engineInstalled else { throw EarsError.notInstalled }

        stop()
        state = .starting
        detail = "Loading Phonon-2.5 English…"
        port = Net.freePort()
        let log = try logHandle(named: "ears.log")

        let process = Process()
        process.executableURL = fermion
        process.arguments = ["serve", Self.modelAlias, "--port", "\(port)"]
        process.currentDirectoryURL = root
        process.standardOutput = log
        process.standardError = log
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                if case .ready = self.state {
                    self.state = .failed("The ears engine exited (\(proc.terminationStatus)).")
                }
            }
        }

        DebugLog.write("ears serve spawn port=\(port) bin=\(fermion.path)")
        do {
            try process.run()
        } catch {
            DebugLog.write("ears spawn failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
            throw error
        }
        self.process = process

        // First launch downloads the 158 MB model, then compiles Metal shaders (~20 s).
        let deadline = Date().addingTimeInterval(420)
        while Date() < deadline {
            if Task.isCancelled { stop(); throw CancellationError() }
            if await healthy() {
                DebugLog.write("ears healthy port=\(port)")
                state = .ready
                detail = "Phonon-2.5 English · ready"
                return
            }
            if self.process == nil {
                throw EarsError.startFailed
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        stop()
        state = .failed("The ears engine did not become ready.")
        throw EarsError.startFailed
    }

    func stop() {
        process?.terminate()
        process = nil
        port = 0
        if engineInstalled, !state.isBusy {
            state = .readyEngine
        }
    }

    func remove() {
        stop()
        try? FileManager.default.removeItem(at: venv)
        let cache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/fermion/speech")
            .appendingPathComponent(Self.modelRepo.replacingOccurrences(of: "/", with: "__"))
        try? FileManager.default.removeItem(at: cache)
        state = .absent
        detail = ""
    }

    private func healthy() async -> Bool {
        guard port > 0,
              let url = URL(string: "http://127.0.0.1:\(port)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Runtime

    /// Prefer a uv already on the machine; otherwise fetch the pinned static binary.
    private func uvBinary() async throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/uv").path,
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let binDir = root.appendingPathComponent("bin", isDirectory: true)
        let local = binDir.appendingPathComponent("uv")
        if FileManager.default.isExecutableFile(atPath: local.path) { return local }

        state = .installing("Fetching the engine runtime (14 MB)…")
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)

        let archive = AppPaths.downloads.appendingPathComponent("uv-aarch64-apple-darwin.tar.gz")
        let remote = RemoteFile(
            fileName: "uv-aarch64-apple-darwin.tar.gz",
            url: URL(string: "https://github.com/astral-sh/uv/releases/download/0.13.6/uv-aarch64-apple-darwin.tar.gz")!,
            bytes: 14_260_000,
            sha256: "60fbd5c8a1ed681845eea28d9d622fcde03c51e91a43465b64a1e17db1ed3472"
        )
        let download = ResumableDownload(
            file: remote,
            destination: archive,
            resumeURL: AppPaths.downloads.appendingPathComponent("uv.resume")
        ) { _, _ in }
        _ = try await download.start()

        let extract = binDir.appendingPathComponent("uv-extract", isDirectory: true)
        try? FileManager.default.removeItem(at: extract)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                    process.arguments = ["-xzf", archive.path, "-C", extract.path]
                    try FileManager.default.createDirectory(at: extract, withIntermediateDirectories: true)
                    try process.run()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else { throw EarsError.installFailed }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let unpacked = extract.appendingPathComponent("uv-aarch64-apple-darwin/uv")
        guard FileManager.default.isExecutableFile(atPath: unpacked.path) else {
            throw EarsError.installFailed
        }
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: unpacked, to: local)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: local.path)
        return local
    }

    private func logHandle(named name: String) throws -> FileHandle {
        AppPaths.ensureDirectories()
        let url = AppPaths.logs.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try FileHandle(forWritingTo: url)
    }

    private func run(
        _ arguments: [String],
        log: FileHandle,
        label: String,
        timeout: TimeInterval = 900
    ) async throws {
        guard let executable = arguments.first else { throw EarsError.installFailed }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = Array(arguments.dropFirst())
            process.standardOutput = log
            process.standardError = log
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: EarsError.commandFailed(label, proc.terminationStatus))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }
        }
    }
}

enum EarsError: LocalizedError {
    case notInstalled
    case installFailed
    case startFailed
    case commandFailed(String, Int32)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "The ears engine is not installed. Install it in Settings."
        case .installFailed: "The ears engine could not be installed."
        case .startFailed: "The ears engine did not start."
        case .commandFailed(let label, let code): "\(label) failed with exit code \(code). See ~/Library/Application Support/PhononCharacters/Logs."
        }
    }
}
