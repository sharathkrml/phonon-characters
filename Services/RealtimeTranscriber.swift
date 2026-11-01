import Foundation

/// Live transcription from Phonon-2.5 English over Fermion's `/v1/audio/stream` WebSocket.
/// Partials arrive roughly twice a second and replace the in-flight hypothesis; finals commit.
@MainActor
final class RealtimeTranscriber: ObservableObject {
    @Published private(set) var committed = ""
    @Published private(set) var current = ""
    @Published private(set) var isConnected = false
    @Published private(set) var errorText: String?
    let sampleRate: Double = 16_000

    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var done = false
    private var closing = false

    var text: String {
        [committed, current]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func connect(port: Int) async throws {
        cancel()
        committed = ""
        current = ""
        errorText = nil
        done = false
        closing = false

        guard let url = URL(string: "ws://127.0.0.1:\(port)/v1/audio/stream") else {
            throw URLError(.badURL)
        }
        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        DebugLog.write("ws resume \(url.absoluteString)")
        task.resume()

        let config: [String: Any] = ["sample_rate": sampleRate, "format": "pcm_s16le"]
        if let data = try? JSONSerialization.data(withJSONObject: config),
           let text = String(data: data, encoding: .utf8) {
            try? await task.send(.string(text))
        }
        isConnected = true
        DebugLog.write("ws config sent; connected")
        receiveTask = Task { [weak self] in await self?.receiveLoop() }
    }

    /// Raw mono PCM16 at `sampleRate`, sent as binary frames.
    func append(_ pcm16: Data) {
        guard isConnected, !pcm16.isEmpty, let socket else { return }
        Task { try? await socket.send(.data(pcm16)) }
    }

    /// Ends the stream and waits for the authoritative transcript.
    func finish() async -> String {
        guard isConnected, let socket else {
            close()
            return text
        }
        if let data = try? JSONSerialization.data(withJSONObject: ["type": "end"]),
           let message = String(data: data, encoding: .utf8) {
            try? await socket.send(.string(message))
        }

        let deadline = Date().addingTimeInterval(6)
        while !done, Date() < deadline, isConnected {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        close()
        return text
    }

    func cancel() {
        close()
        committed = ""
        current = ""
        errorText = nil
    }

    private func close() {
        closing = true
        isConnected = false
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let socket {
            do {
                let message = try await socket.receive()
                handle(message)
            } catch {
                DebugLog.write("ws receive error: \(error.localizedDescription)")
                if !closing, errorText == nil {
                    errorText = "Live transcription stopped: \(error.localizedDescription)"
                }
                isConnected = false
                break
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return }

        DebugLog.write("ws event \(type)")
        switch type {
        case "partial":
            current = object["text"] as? String ?? ""

        case "final":
            let segment = (object["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !segment.isEmpty {
                committed = committed.isEmpty ? segment : committed + " " + segment
            }
            current = ""

        case "done":
            let full = (object["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !full.isEmpty { committed = full }
            current = ""
            done = true

        case "error":
            let message = object["message"] as? String ?? "The ears engine reported an error."
            DebugLog.write("ws error: \(message)")
            errorText = message
            done = true

        default:
            break
        }
    }
}
