import SwiftUI

/// The cast rail: one portrait medallion per character, the current one ringed in gold.
struct RosterRail: View {
    let characters: [Persona]
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            arrow(.left) { onSelect(max(selected - 1, 0)) }

            HStack(spacing: 7) {
                ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                    medallion(character, current: index == selected) {
                        onSelect(index)
                    }
                }
            }

            arrow(.right) { onSelect(min(selected + 1, characters.count - 1)) }
        }
        .padding(.vertical, 2)
    }

    private func medallion(_ character: Persona, current: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(character.palette.ink)

                if let thumb = PortraitArt.thumbnail(character.id, size: 34) {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: character.emblem.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(character.palette.accent)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(
                    current ? AnyShapeStyle(Theme.gilt) : AnyShapeStyle(Theme.parchment.opacity(0.22)),
                    lineWidth: current ? 2 : 1
                )
            )
            .scaleEffect(current ? 1.14 : 1)
            .shadow(color: current ? character.palette.accent.opacity(0.55) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .help(character.name)
        .accessibilityLabel(character.name)
        .accessibilityAddTraits(current ? .isSelected : [])
    }

    private func arrow(_ direction: Direction, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.parchment.opacity(0.6))
                .frame(width: 24, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction == .left ? "Previous character" : "Next character")
    }

    private enum Direction { case left, right }
}
