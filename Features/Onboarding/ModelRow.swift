import SwiftUI

struct ModelRow: View {
    let package: ModelPackage
    @ObservedObject var models: ModelStore
    var compact = false

    private var status: ModelStore.Status { models.status(of: package.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.parchment)
                        .overlay(Circle().strokeBorder(Theme.gilt.opacity(0.7), lineWidth: 1.2))
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.giltDeep)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(package.title)
                            .font(Theme.body(14, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if !package.required {
                            Text("optional")
                                .font(Theme.body(9.5, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(Theme.inkSoft)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.ink.opacity(0.06)))
                        }
                    }
                    Text(package.subtitle)
                        .font(Theme.body(11.5))
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer(minLength: 12)

                trailing
            }

            if case .downloading(let progress, let received, let total) = status {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(Theme.giltDeep)
                    HStack {
                        Text("\(AppPaths.megabytes(received)) of \(AppPaths.megabytes(total))")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                    }
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.inkSoft)
                }
            }

            if case .failed(let message) = status {
                Text(message)
                    .font(Theme.body(10.5))
                    .foregroundStyle(.red.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, compact ? 2 : 4)
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .ready:
            HStack(spacing: 10) {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0x4C7A3A))
                Text(AppPaths.megabytes(models.bytesOnDisk(package.id)))
                    .font(Theme.body(10.5))
                    .foregroundStyle(Theme.inkSoft)
                Button("Delete") {
                    models.delete(package.id)
                }
                .font(Theme.body(11, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft)
            }

        case .downloading:
            Button("Cancel") { models.cancel(package.id) }
                .font(Theme.body(11, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSoft)

        case .verifying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
            }

        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Installing…").font(Theme.body(11)).foregroundStyle(Theme.inkSoft)
            }

        case .absent, .failed:
            Button {
                models.download(package.id)
            } label: {
                Text(status.isFailed ? "Retry" : "Download")
                    .font(Theme.label(11.5, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.gilt))
            }
            .buttonStyle(.plain)
        }
    }

    private var symbol: String {
        switch package.id {
        case .voice: "waveform"
        case .brain: "brain.head.profile"
        }
    }
}

private extension ModelStore.Status {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
