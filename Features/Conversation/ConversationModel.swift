import AVFoundation
import Combine
import PhononTTS
import SwiftUI

@MainActor
final class ConversationModel: ObservableObject {
    enum Phase: Equatable {
        case idle, listening, thinking, speaking
    }

    struct Message: Identifiable, Equatable {
        enum Role: Equatable { case user, assistant }

        let id = UUID()
        var role: Role
        var text: String
        var streaming = false
    }

    let models: ModelStore
    let ears: EarsEngine
    let phonon = PhononService()
    let brain = LlamaServer(name: "brain")
    let transcriber = RealtimeTranscriber()

    private let capture = AudioCapture()
    private let keys = KeyMonitor()
    private let prefs = Preferences.shared
    private var cancellables: Set<AnyCancellable> = []

    @Published var selectedIndex: Int
    @Published var phase: Phase = .idle
    @Published var threads: [String: [Message]] = [:]
    @Published var errorText: String?
    @Published var hint: String?
    @Published var micDenied = false
    @Published var isListening = false
    @Published var busyLoading = false
    @Published var micLevel: Float = 0
    @Published var suggestedInputUID: String?

    private var responseTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var greetTask: Task<Void, Never>?
    private var brainStart: Task<Void, Error>?
    private var finalizeTask: Task<Void, Never>?
    private var pendingPCM = Data()
    private var didFinalize = false
    private var pressedAt: Date?
    private var audioEnd = Date.distantPast
    private var visited: Set<String> = []
    private var started = false
    private var loggedAudio = false
    private var sessionPeak: Float = 0

    init(models: ModelStore, ears: EarsEngine) {
        self.models = models
        self.ears = ears
        let stored = Persona.all.firstIndex { $0.id == Preferences.shared.selectedCharacterID } ?? 0
        selectedIndex = stored

        phonon.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        transcriber.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        brain.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        ears.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.shutdown()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .modelWillDelete,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let kind = note.object as? ModelKind else { return }
            Task { @MainActor in
                switch kind {
                case .brain: self?.brain.stop()
                case .voice: self?.phonon.unload()
                }
            }
        }
    }

    // MARK: - Derived state

    var character: Persona {
        Persona.all[min(max(selectedIndex, 0), Persona.all.count - 1)]
    }

    var messages: [Message] { threads[character.id] ?? [] }

    var latestReply: Message? {
        messages.last { $0.role == .assistant }
    }

    var lastUserMessage: String? {
        messages.last { $0.role == .user }?.text
    }

    var isSpeaking: Bool { phase == .speaking }

    var isBusy: Bool { phase == .thinking || phase == .speaking }

    // MARK: - Lifecycle

    func activate() {
        guard !started else { return }
        started = true
        DebugLog.write("activate voice=\(models.voiceReady) brain=\(models.brainReady) ears=\(ears.engineInstalled)")
        keys.onSpaceDown = { [weak self] in self?.spaceDown() }
        keys.onSpaceUp = { [weak self] in self?.spaceUp() }
        keys.onEscape = { [weak self] in self?.escape() ?? false }
        keys.onPrevious = { [weak self] in self?.step(-1) }
        keys.onNext = { [weak self] in self?.step(1) }
        keys.start()

        if models.voiceReady {
            Task {
                do { try await phonon.loadIfNeeded() } catch {
                    errorText = error.localizedDescription
                }
            }
        }
        if models.brainReady {
            Task { try? await ensureBrain() }
        }
        if ears.engineInstalled {
            // Ask once, on launch, so the first held Space never waits on a dialog.
            Task { _ = await MicPermission.request() }
            // Warm the ear server so the first hold is not waiting on a cold model load.
            Task { try? await ears.start() }
        }
        if !visited.contains(character.id) {
            visited.insert(character.id)
            let first = character
            greetTask = Task { await greet(first) }
        }
    }

    func deactivate() {
        keys.stop()
    }

    func shutdown() {
        keys.stop()
        interrupt()
        capture.stop()
        transcriber.cancel()
        brain.stop()
        ears.stop()
    }

    // MARK: - Characters

    func step(_ delta: Int) {
        let count = Persona.all.count
        select(((selectedIndex + delta) % count + count) % count)
    }

    func select(_ index: Int) {
        let count = Persona.all.count
        let next = ((index % count) + count) % count
        guard next != selectedIndex else { return }
        interrupt()
        selectedIndex = next
        prefs.selectedCharacterID = character.id

        let char = character
        guard !visited.contains(char.id) else { return }
        visited.insert(char.id)
        greetTask = Task { await greet(char) }
    }

    // MARK: - Sending

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        interrupt()
        let char = character
        append(Message(role: .user, text: text), to: char.id)
        let reply = Message(role: .assistant, text: "", streaming: true)
        append(reply, to: char.id)
        phase = .thinking

        responseTask = Task { [weak self] in
            await self?.respond(char: char, replyID: reply.id)
        }
    }

    private func respond(char: Persona, replyID: UUID) async {
        do {
            try await ensureBrain()
            let history: [(String, String)] = messages(for: char.id)
                .filter { $0.id != replyID }
                .map { ($0.role == .user ? "user" : "assistant", $0.text) }
            let prompt = PersonaPrompt.messages(for: char, history: history)

            var buffer = ""
            for try await token in BrainClient.stream(port: brain.port, messages: prompt) {
                try Task.checkCancellation()
                update(charID: char.id, messageID: replyID) { $0.text += token }
                buffer += token
                while let sentence = SentenceSplitter.take(&buffer) {
                    try Task.checkCancellation()
                    try await speak(sentence, char: char)
                }
            }

            let tail = SentenceSplitter.sanitize(buffer)
            if !tail.isEmpty {
                try await speak(tail, char: char)
            }
            update(charID: char.id, messageID: replyID) { $0.streaming = false }
            await waitForAudio()
            phonon.finishSpeaking()
            if phase != .listening { phase = .idle }
        } catch is CancellationError {
            update(charID: char.id, messageID: replyID) { $0.streaming = false }
        } catch {
            update(charID: char.id, messageID: replyID) { $0.streaming = false }
            errorText = error.localizedDescription
            if phase != .listening { phase = .idle }
        }
    }

    private func greet(_ char: Persona) async {
        do {
            try await phonon.loadIfNeeded()
            try await phonon.setVoice(char.voice)
            if messages(for: char.id).isEmpty {
                append(Message(role: .assistant, text: char.greeting), to: char.id)
            }
            guard prefs.autoSpeak else { return }
            phase = .speaking
            let started = Date()
            if let stats = try await phonon.speak(char.greeting, voice: char.voice) {
                noteAudio(stats: stats, started: started)
            }
            await waitForAudio()
            phonon.finishSpeaking()
            if phase == .speaking { phase = .idle }
        } catch {
            errorText = error.localizedDescription
            if phase == .speaking { phase = .idle }
        }
    }

    private func speak(_ text: String, char: Persona) async throws {
        guard prefs.autoSpeak else { return }
        if phase != .speaking { phase = .speaking }
        let started = Date()
        if let stats = try await phonon.speak(text, voice: char.voice) {
            noteAudio(stats: stats, started: started)
        }
    }

    private func noteAudio(stats: SpeechStats, started: Date) {
        let elapsed = Date().timeIntervalSince(started)
        let remaining = max(0, stats.audioSeconds - elapsed)
        audioEnd = max(audioEnd, Date().addingTimeInterval(remaining))
    }

    private func waitForAudio() async {
        while Date() < audioEnd {
            if Task.isCancelled { return }
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
    }

    // MARK: - Interruption

    func interrupt() {
        responseTask?.cancel()
        responseTask = nil
        greetTask?.cancel()
        greetTask = nil
        phonon.stop()
        audioEnd = .distantPast
        if phase != .listening { phase = .idle }
    }

    // MARK: - Push to talk

    func beginPushToTalk() { spaceDown() }

    func endPushToTalk() { spaceUp() }

    private func spaceDown() {
        guard !isListening else { return }
        DebugLog.write("spaceDown earsInstalled=\(ears.engineInstalled) earsState=\(ears.state)")
        interrupt()
        hint = nil
        guard ears.engineInstalled else {
            hint = "Install Ears in Settings to talk to your character."
            return
        }
        guard !micDenied else {
            hint = "Microphone access is off. Enable it in System Settings → Privacy & Security → Microphone."
            return
        }

        finalizeTask?.cancel()
        suggestedInputUID = nil
        isListening = true
        pressedAt = Date()
        phase = .listening
        loggedAudio = false
        sessionPeak = 0
        pendingPCM = Data()
        didFinalize = false

        startTask = Task { [weak self] in await self?.beginListening() }
    }

    /// Capture starts before the ear server is ready. Audio is buffered and flushed once the
    /// stream connects, so a cold first hold does not lose the sentence.
    private func beginListening() async {
        do {
            let granted = await MicPermission.request()
            DebugLog.write("mic permission granted=\(granted)")
            guard granted else {
                micDenied = true
                hint = "Microphone access is off. Enable it in System Settings → Privacy & Security → Microphone."
                stopListeningUI()
                return
            }
            try Task.checkCancellation()

            DebugLog.write("audio capture start rate=\(transcriber.sampleRate) input=\(prefs.inputDeviceUID)")
            try capture.start(sampleRate: transcriber.sampleRate, deviceUID: prefs.inputDeviceUID) { [weak self] data in
                let level = Self.rms(data)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !self.loggedAudio {
                        self.loggedAudio = true
                        DebugLog.write("first audio chunk bytes=\(data.count)")
                    }
                    if level > self.sessionPeak { self.sessionPeak = level }
                    self.micLevel = level
                    if level > 0.02, self.suggestedInputUID != nil {
                        self.hint = nil
                        self.suggestedInputUID = nil
                    }
                    if self.transcriber.isConnected {
                        self.transcriber.append(data)
                    } else if self.pendingPCM.count < 16_000 * 2 * 30 {
                        self.pendingPCM.append(data)
                    }
                }
            }

            if !ears.isReady {
                DebugLog.write("ears.start begin")
                try await ears.start()
                DebugLog.write("ears.start ready port=\(ears.port)")
            }

            try Task.checkCancellation()
            DebugLog.write("transcriber.connect port=\(ears.port)")
            try await transcriber.connect(port: ears.port)
            DebugLog.write("transcriber connected=\(transcriber.isConnected)")

            if !pendingPCM.isEmpty {
                DebugLog.write("flush buffered audio bytes=\(pendingPCM.count)")
                transcriber.append(pendingPCM)
                pendingPCM = Data()
            }
        } catch is CancellationError {
            DebugLog.write("listening cancelled")
            stopListeningUI()
        } catch {
            DebugLog.write("listening error: \(error.localizedDescription)")
            errorText = error.localizedDescription
            stopListeningUI()
        }
    }

    private func spaceUp() {
        guard isListening else { return }
        isListening = false
        let held = Date().timeIntervalSince(pressedAt ?? Date())
        pressedAt = nil

        guard held >= 0.4 else {
            startTask?.cancel()
            startTask = nil
            finalizeTask?.cancel()
            capture.stop()
            transcriber.cancel()
            pendingPCM = Data()
            if phase == .listening { phase = .idle }
            return
        }

        let start = startTask
        startTask = nil
        finalizeTask = Task { [weak self] in
            await start?.value
            await self?.finalizeListening()
        }
    }

    private func finalizeListening() async {
        guard !didFinalize else { return }
        didFinalize = true
        capture.stop()

        guard transcriber.isConnected else {
            transcriber.cancel()
            pendingPCM = Data()
            if phase == .listening { phase = .idle }
            return
        }
        if !pendingPCM.isEmpty {
            transcriber.append(pendingPCM)
            pendingPCM = Data()
        }

        let text = await transcriber.finish()
        DebugLog.write("finish transcript chars=\(text.count) peak=\(sessionPeak)")
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            if sessionPeak < 0.01 {
                let name = prefs.inputDeviceUID.isEmpty
                    ? "the system default input"
                    : (AudioDevices.name(for: prefs.inputDeviceUID) ?? "this input")
                hint = "No signal from \(name)."
                suggestedInputUID = Self.suggestedAlternative(to: prefs.inputDeviceUID)
                DebugLog.write("silent hold peak=\(sessionPeak) uid=\(prefs.inputDeviceUID)")
            }
            if phase == .listening { phase = .idle }
            return
        }
        send(clean)
    }

    private func escape() -> Bool {
        if isListening {
            startTask?.cancel()
            startTask = nil
            finalizeTask?.cancel()
            finalizeTask = nil
                suggestedInputUID = nil
            isListening = false
            pendingPCM = Data()
            capture.stop()
            transcriber.cancel()
            if phase == .listening { phase = .idle }
            return true
        }
        if phase == .thinking || phase == .speaking {
            interrupt()
            return true
        }
        return false
    }

    private func stopListeningUI() {
        isListening = false
        startTask = nil
        finalizeTask?.cancel()
        finalizeTask = nil
        suggestedInputUID = nil
        pendingPCM = Data()
        didFinalize = false
        micLevel = 0
        capture.stop()
        transcriber.cancel()
        if phase == .listening { phase = .idle }
    }

    func useSuggestedInput() {
        guard let uid = suggestedInputUID else { return }
        prefs.inputDeviceUID = uid
        suggestedInputUID = nil
        hint = "Input switched to \(AudioDevices.name(for: uid) ?? "the new microphone"). Hold Space again."
        DebugLog.write("input fallback uid=\(uid)")
    }

    private static func suggestedAlternative(to uid: String) -> String? {
        let inputs = AudioDevices.inputs()
        if let builtIn = inputs.first(where: {
            $0.id == "BuiltInMicrophoneDevice" || $0.name.localizedCaseInsensitiveContains("MacBook")
        }), builtIn.id != uid {
            return builtIn.id
        }
        return inputs.first(where: { $0.id != uid })?.id
    }

    private static func rms(_ data: Data) -> Float {
        let count = data.count / MemoryLayout<Int16>.size
        guard count > 0 else { return 0 }
        let level: Float = data.withUnsafeBytes { raw in
            guard let samples = raw.bindMemory(to: Int16.self).baseAddress else { return 0 }
            var sum: Float = 0
            for index in 0..<count {
                let value = Float(samples[index]) / 32768
                sum += value * value
            }
            return sqrt(sum / Float(count)) * 6
        }
        return min(1, level)
    }

    // MARK: - Helpers

    private func ensureBrain() async throws {
        if brain.state.isReady { return }
        guard models.brainReady else { throw LlamaError.modelMissing }

        // Two callers (launch and the first message) must share one process, not kill each other.
        if let brainStart {
            try await brainStart.value
            return
        }

        let model = ModelCatalog.destination(for: ModelCatalog.brain.files[0])
        let task = Task { [brain] in
            try await brain.start(model: model)
        }
        brainStart = task
        busyLoading = true
        defer { busyLoading = false }
        do {
            try await task.value
            brainStart = nil
        } catch {
            brainStart = nil
            throw error
        }
    }

    private func messages(for id: String) -> [Message] {
        threads[id] ?? []
    }

    private func append(_ message: Message, to charID: String) {
        threads[charID, default: []].append(message)
    }

    private func update(charID: String, messageID: UUID, _ change: (inout Message) -> Void) {
        guard var list = threads[charID],
              let index = list.firstIndex(where: { $0.id == messageID }) else { return }
        change(&list[index])
        threads[charID] = list
    }

    func clearConversation() {
        interrupt()
        threads[character.id] = []
    }
}

extension Notification.Name {
    static let modelWillDelete = Notification.Name("phonon.modelWillDelete")
}
