import Foundation

/// A `llama.cpp` server child process holding one model. Two of these run: the brain (LFM3 1.7B)
/// and the ears (LFM3 Audio 2B). They talk OpenAI over localhost.
@MainActor
final class LlamaServer: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case ready
        case failed(String)

        var isReady: Bool { self == .ready }
    }

    let name: String
    @Published private(set) var state: State = .stopped
    @Published private(set) var port: Int = 0
    @Published private(set) var lastLog: String = ""

    private var process: Process?
    private var logHandle: FileHandle?
    private var ownsProcess = false

    init(name: String) {
        self.name = name
        LlamaServerRegistry.register(self)
    }

    var baseURL: URL? {
        guard port > 0 else { return nil }
        return URL(string: "http://127.0.0.1:\(port)")
    }

    func start(model: URL, mmproj: URL? = nil, context: Int = 4096) async throws {
        if state.isReady { return }
        stop()

        guard FileManager.default.fileExists(atPath: model.path) else {
            state = .failed("Model file is missing.")
            throw LlamaError.modelMissing
        }
        guard let binary = LlamaServer.binaryURL else {
            state = .failed("The llama runtime is missing from the app.")
            throw LlamaError.binaryMissing
        }

        state = .starting
        port = Net.freePort()
        let logURL = AppPaths.logs.appendingPathComponent("\(name).log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        logHandle = try? FileHandle(forWritingTo: logURL)
        lastLog = ""

        var args = [
            "serve",
            "-m", model.path,
            "-c", "\(context)",
            "--host", "127.0.0.1",
            "--port", "\(port)",
            "--jinja",
            "-ngl", "99",
        ]
        if let mmproj {
            args += ["--mmproj", mmproj.path]
        }

        let process = Process()
        process.executableURL = binary
        process.arguments = args
        process.currentDirectoryURL = binary.deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["LLAMA_LOG_LEVEL"] = "warn"
        process.environment = environment
        process.standardOutput = logHandle
        process.standardError = logHandle
        ownsProcess = true
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self, self.ownsProcess else { return }
                self.process = nil
                self.ownsProcess = false
                if self.state != .stopped {
                    self.state = .failed("The \(self.name) process exited (\(proc.terminationStatus)).")
                }
            }
        }

        do {
            try process.run()
        } catch {
            ownsProcess = false
            state = .failed(error.localizedDescription)
            throw error
        }
        self.process = process

        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            if Task.isCancelled { stop(); throw CancellationError() }
            if await isHealthy() {
                state = .ready
                return
            }
            if self.process == nil {
                let detail = readLogTail()
                state = .failed("The \(name) process stopped while loading.")
                throw LlamaError.launchFailed(detail.isEmpty ? "No log output." : String(detail.suffix(400)))
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        stop()
        let detail = readLogTail()
        state = .failed(detail.isEmpty ? "Timed out loading \(name)." : detail)
        throw LlamaError.launchFailed(detail)
    }

    func stop() {
        ownsProcess = false
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        logHandle = nil
        port = 0
        state = .stopped
    }

    func readLogTail() -> String {
        let url = AppPaths.logs.appendingPathComponent("\(name).log")
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > 4000 ? size - 4000 : 0
        try? handle.seek(toOffset: start)
        let data = (try? handle.readToEnd()) ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        lastLog = text
        return text
    }

    private func isHealthy() async -> Bool {
        guard let baseURL else { return false }
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Locating the bundled runtime

    static var binaryURL: URL? {
        if let resource = Bundle.main.resourceURL?
            .appendingPathComponent("llama", isDirectory: true)
            .appendingPathComponent("llama"),
           FileManager.default.isExecutableFile(atPath: resource.path) {
            return resource
        }
        // Development fallback: the repository copy.
        let dev = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/llama/llama")
        return FileManager.default.isExecutableFile(atPath: dev.path) ? dev : nil
    }

}

enum LlamaError: LocalizedError {
    case binaryMissing
    case modelMissing
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryMissing: "The bundled llama runtime could not be found."
        case .modelMissing: "The model file is missing. Download it from Settings."
        case .launchFailed(let detail): "The model did not start. \(detail)"
        }
    }
}

/// Keeps every server reachable so app termination can shut them down.
enum LlamaServerRegistry {
    private static var servers: [LlamaServer] = []
    private static let lock = NSLock()

    static func register(_ server: LlamaServer) {
        lock.lock()
        servers.append(server)
        lock.unlock()
    }

    static func stopAll() {
        lock.lock()
        let all = servers
        lock.unlock()
        for server in all {
            MainActor.assumeIsolated { server.stop() }
        }
    }
}
