import SwiftUI

struct OnboardingView: View {
    @ObservedObject var models: ModelStore
    @ObservedObject var ears: EarsEngine
    @ObservedObject var prefs = Preferences.shared

    var body: some View {
        ZStack {
            PaperBackground()

            HStack(alignment: .center, spacing: 54) {
                introduction
                    .frame(maxWidth: 420, alignment: .leading)

                modelsCard
                    .frame(width: 470)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 44)
            .frame(maxWidth: 1080)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Phonon\nCharacters")
                .font(Theme.display(54))
                .lineSpacing(-2)
                .foregroundStyle(Theme.ink)

            Text("Twelve voices with something to say. All of it happens on this Mac.")
                .font(Theme.display(17))
                .lineSpacing(5)
                .foregroundStyle(Theme.inkSoft)

            VStack(alignment: .leading, spacing: 12) {
                feature("waveform", "Twelve character voices, straight from Phonon.")
                feature("brain.head.profile", "A 1.7B brain answers in character, offline.")
                feature("ear", "Hold Space and watch your words appear as you speak.")
                feature("lock", "Nothing is uploaded. Airplane mode works.")
            }
            .padding(.top, 4)

            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                Text("\(AppPaths.megabytes(AppPaths.freeBytes())) free on this Mac")
            }
            .font(Theme.body(11.5))
            .foregroundStyle(Theme.inkSoft.opacity(0.8))
            .padding(.top, 6)
        }
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .frame(width: 18)
            Text(text)
                .font(Theme.body(13))
                .foregroundStyle(Theme.ink.opacity(0.82))
        }
    }

    private var modelsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set up your voices")
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.ink)
                Text("Download once. They stay on disk and work offline.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
            }

            VStack(spacing: 4) {
                ForEach(ModelCatalog.all) { package in
                    ModelRow(package: package, models: models)
                    InkRule(opacity: 0.08)
                }
                EarsRow(ears: ears)
            }

            InkRule(opacity: 0.10)

            Button {
                prefs.onboarded = true
            } label: {
                HStack {
                    Text(models.coreReady ? "Enter the stage" : "Download the voice and brain to continue")
                        .font(Theme.body(13, weight: .semibold))
                    Spacer()
                    if models.coreReady {
                        Image(systemName: "arrow.right")
                    } else if !models.voiceReady || !models.brainReady {
                        ProgressView().controlSize(.small)
                    }
                }
                .foregroundStyle(models.coreReady ? Theme.paper : Theme.inkSoft)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(models.coreReady ? Theme.ink : Theme.ink.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .disabled(!models.coreReady)

            Text("Voice and brain are required. Ears are only for the microphone.")
                .font(Theme.body(10.5))
                .foregroundStyle(Theme.inkSoft.opacity(0.7))
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.paper.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 24, y: 10)
        )
    }
}
