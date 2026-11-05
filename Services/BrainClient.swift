import Foundation

enum BrainClient {
    struct Message: Codable {
        let role: String
        let content: String
    }

    enum BrainError: LocalizedError {
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .http(let code, let body): "The brain answered HTTP \(code). \(body)"
            }
        }
    }

    static func stream(
        port: Int,
        messages: [Message],
        maxTokens: Int = 160,
        onTokensPerSecond: (@Sendable (Double) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: "http://127.0.0.1:\(port)/v1/chat/completions") else {
                        throw URLError(.badURL)
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: Any] = [
                        "model": "local",
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true,
                        // The final SSE chunk then carries llama.cpp's decode timings.
                        "stream_options": ["include_usage": true],
                        "temperature": 0.85,
                        "top_p": 0.95,
                        "max_tokens": maxTokens,
                        // LFM3 thinks before answering unless told not to. We want the spoken line.
                        "chat_template_kwargs": ["enable_thinking": false],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    guard http.statusCode == 200 else {
                        var text = ""
                        for try await line in bytes.lines {
                            text += line
                            if text.count > 400 { break }
                        }
                        throw BrainError.http(http.statusCode, text)
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }
                        if let timings = json["timings"] as? [String: Any],
                           let speed = timings["predicted_per_second"] as? Double,
                           speed > 0 {
                            onTokensPerSecond?(speed)
                        }
                        guard let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let token = delta["content"] as? String
                        else { continue }
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One non-streaming turn that lets the model choose a tool. llama.cpp's `--jinja` template
    /// turns the tools into real `tool_calls`, so the app never parses an effect out of prose.
    static func completeToolCall(
        port: Int,
        system: String,
        user: String,
        tools: [BrainTool],
        maxTokens: Int = 80
    ) async -> BrainToolCall? {
        guard let url = URL(string: "http://127.0.0.1:\(port)/v1/chat/completions") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": "local",
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "stream": false,
            "temperature": 0.2,
            "max_tokens": maxTokens,
            "chat_template_kwargs": ["enable_thinking": false],
            "tool_choice": "auto",
            "tools": tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": tool.parameters,
                    ],
                ]
            },
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = httpBody

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let calls = message["tool_calls"] as? [[String: Any]],
              let first = calls.first,
              let function = first["function"] as? [String: Any],
              let name = function["name"] as? String
        else { return nil }

        var arguments: [String: Any] = [:]
        if let text = function["arguments"] as? String,
           let data = text.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = parsed
        } else if let parsed = function["arguments"] as? [String: Any] {
            arguments = parsed
        }
        return BrainToolCall(name: name, arguments: arguments)
    }
}

struct BrainTool {
    let name: String
    let description: String
    let parameters: [String: Any]
}

struct BrainToolCall {
    let name: String
    let arguments: [String: Any]
}

enum PersonaPrompt {
    static func messages(
        for character: Persona,
        history: [(String, String)],
        stageBrief: String? = nil
    ) -> [BrainClient.Message] {
        let rules = """
        Stay fully in character. Answer in at most two short sentences that sound good spoken \
        aloud. Stop when the thought is complete. Never use markdown, bullet points, lists, \
        emoji, asterisks or stage directions. Never mention that you are an AI or a model.
        """
        var system = "\(character.persona)\n\n\(rules)"
        if let stageBrief {
            system += "\n\n\(stageBrief)"
        }
        var list = [BrainClient.Message(role: "system", content: system)]
        for (role, text) in history.suffix(10) {
            list.append(.init(role: role, content: text))
        }
        return list
    }
}

/// Drops `think` blocks from a token stream, including when a tag is split across tokens.
struct ThinkingFilter {
    private var buffer = ""
    private var inside = false

    mutating func feed(_ token: String) -> String {
        buffer += token
        var out = ""
        while true {
            if inside {
                guard let range = buffer.range(of: "</think") else {
                    buffer = String(buffer.suffix(Self.holdback(buffer, tag: "</think")))
                    return out
                }
                guard let end = buffer[range.upperBound...].firstIndex(of: ">") else {
                    buffer = String(buffer[range.lowerBound...])
                    return out
                }
                buffer = String(buffer[buffer.index(after: end)...])
                inside = false
                continue
            }

            let open = buffer.range(of: "<think")
            let close = buffer.range(of: "</think")

            // A closing tag with no opening: everything before it was reasoning that the
            // template never wrapped. Drop the prefix and keep the final answer.
            if let close, open.map({ close.lowerBound < $0.lowerBound }) ?? true {
                guard let end = buffer[close.upperBound...].firstIndex(of: ">") else {
                    buffer = String(buffer[close.lowerBound...])
                    return out
                }
                buffer = String(buffer[buffer.index(after: end)...])
                continue
            }

            if let open {
                out.append(contentsOf: buffer[..<open.lowerBound])
                guard let end = buffer[open.upperBound...].firstIndex(of: ">") else {
                    buffer = String(buffer[open.lowerBound...])
                    return out
                }
                buffer = String(buffer[buffer.index(after: end)...])
                inside = true
                continue
            }

            let keep = max(Self.holdback(buffer, tag: "<think"), Self.holdback(buffer, tag: "</think"))
            out.append(contentsOf: buffer.dropLast(keep))
            buffer = String(buffer.suffix(keep))
            return out
        }
    }

    /// Whatever is left once the stream ends. Text inside an unclosed block is dropped.
    mutating func finish() -> String {
        let rest = inside ? "" : buffer
        buffer = ""
        inside = false
        return rest
    }

    /// Length of a trailing fragment that could still grow into `tag`.
    private static func holdback(_ text: String, tag: String) -> Int {
        for length in stride(from: min(tag.count - 1, text.count), through: 1, by: -1)
        where text.hasSuffix(tag.prefix(length)) {
            return length
        }
        return 0
    }
}

/// Splits a token stream into speakable sentences without losing text.
enum SentenceSplitter {
    static func take(_ buffer: inout String) -> String? {
        let terminators: Set<Character> = [".", "!", "?", "…", "\n"]
        var index = buffer.startIndex
        var lastBoundary: String.Index?
        while index < buffer.endIndex {
            let character = buffer[index]
            if terminators.contains(character) {
                var next = buffer.index(after: index)
                while next < buffer.endIndex, buffer[next] == " " || buffer[next] == "\"" || buffer[next] == "'" {
                    next = buffer.index(after: next)
                }
                let sentence = buffer[buffer.startIndex..<next]
                if sentence.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 {
                    lastBoundary = next
                }
            }
            index = buffer.index(after: index)
        }
        guard let boundary = lastBoundary else { return nil }
        let sentence = String(buffer[buffer.startIndex..<boundary])
        buffer.removeSubrange(buffer.startIndex..<boundary)
        let cleaned = sanitize(sentence)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
