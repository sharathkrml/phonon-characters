import Foundation

struct RemoteFile: Identifiable, Sendable {
    let fileName: String
    let url: URL
    let bytes: Int64
    let sha256: String
    var id: String { fileName }
}

enum ModelKind: String, CaseIterable, Identifiable, Sendable {
    case voice, brain
    var id: String { rawValue }
}

struct ModelPackage: Identifiable, Sendable {
    let id: ModelKind
    let title: String
    let subtitle: String
    let required: Bool
    let files: [RemoteFile]

    var totalBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
}

enum ModelCatalog {
    static let voice = ModelPackage(
        id: .voice,
        title: "Voice",
        subtitle: "Phonon 31M · twelve character voices · Core ML",
        required: true,
        files: [
            RemoteFile(
                fileName: "phonon-31m-en-coreml.zip",
                url: URL(string: "https://github.com/gradium-ai/xn-ptts/releases/download/v0.6.0/phonon-31m-en-coreml.zip")!,
                bytes: 137_300_815,
                sha256: "2869326ab074f55ed5b644e68b1befef69dc51545b73296d49f5b4dab14c4218"
            )
        ]
    )

    static let brain = ModelPackage(
        id: .brain,
        title: "Brain",
        subtitle: "LFM3 1.7B · Q4_K_M · thinks and answers",
        required: true,
        files: [
            RemoteFile(
                fileName: "LFM3-1.7B-Q4_K_M.gguf",
                url: URL(string: "https://huggingface.co/LiquidAI/LFM3-1.7B-GGUF/resolve/main/LFM3-1.7B-Q4_K_M.gguf")!,
                bytes: 1_099_627_808,
                sha256: "3793e1e6e2266919d6e015287221b41100175a98eddaba92e111aed3b05c93c4"
            )
        ]
    )

    static let all: [ModelPackage] = [voice, brain]

    static func package(_ kind: ModelKind) -> ModelPackage {
        switch kind {
        case .voice: voice
        case .brain: brain
        }
    }

    static func destination(for file: RemoteFile) -> URL {
        AppPaths.models.appendingPathComponent(file.fileName)
    }
}
