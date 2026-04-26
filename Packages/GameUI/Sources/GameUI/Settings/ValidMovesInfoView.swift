import SwiftUI
import GameApp

public struct ValidMovesInfoView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Intro
                    BulletPoint(text: "Valid Moves shows how many possible connections remain on the board.")

                    BulletPoint(text: "The counter changes color as moves decrease, giving you a quick visual warning.")

                    // MARK: - Color Key
                    Text("Color Guide")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        .padding(.top, 4)

                    VStack(spacing: 10) {
                        ColorRow(
                            range: "20 +",
                            color: .green,
                            description: "Plenty of moves – keep playing!"
                        )
                        ColorRow(
                            range: "10 – 19",
                            color: .yellow,
                            description: "Getting low – plan ahead."
                        )
                        ColorRow(
                            range: "1 – 9",
                            color: .orange,
                            description: "Danger zone – consider a power-up."
                        )
                        ColorRow(
                            range: "0",
                            color: .red,
                            description: "No moves left!"
                        )
                    }

                    // MARK: - Low on Moves Alert
                    Text("Low on Moves Alert")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        .padding(.top, 8)

                    BulletPoint(text: "When your valid moves drop to 5 or below, a \"Low on Moves\" warning pops up.")

                    BulletPoint(text: "You can choose to use a power-up or continue playing.")

                    AlertPreview(
                        title: "Low On Moves",
                        message: "You are low on moves. Want to use a powerup to free up moves?",
                        buttons: ["Use Powerup", "Continue"],
                        accentColor: .orange
                    )

                    BulletPoint(text: "The alert re-arms once your valid moves go back above 5 (e.g., after using a power-up).")

                    // MARK: - Out of Moves Alert
                    Text("Out of Moves Alert")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                        .padding(.top, 8)

                    BulletPoint(text: "When valid moves reach 0, the \"Out of Moves\" recovery screen appears.")

                    BulletPoint(text: "You can purchase a power-up (Hammer, Swap, or MegaMerge) to free up moves and keep playing.")

                    AlertPreview(
                        title: "Out of Moves!",
                        message: "Continue?",
                        buttons: ["Use Power-Up", "No Thanks", "🏠 Home"],
                        accentColor: .red
                    )

                    BulletPoint(text: "\"No Thanks\" ends the game. The home button lets you leave without ending — the alert will reappear when you return.")

                    // MARK: - Tip
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 18))
                            .padding(.top, 2)
                        Text("Tip: Longer chains create more board movement, opening up new connections and keeping your valid moves count high.")
                            .font(.avenirNext(size: GameFonts.calloutSize, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Valid Moves")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
                    }
                }
            }
        }
    }
}

// MARK: - Bullet Point

private struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.primary)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            Text(text)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
        }
    }
}

// MARK: - Color Row

private struct ColorRow: View {
    let range: String
    let color: Color
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            // Color swatch
            Text(range)
                .font(.avenirNext(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 56, alignment: .center)

            // Divider dot
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(description)
                .font(.avenirNext(size: GameFonts.calloutSize, weight: .regular))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Alert Preview

private struct AlertPreview: View {
    let title: String
    let message: String
    let buttons: [String]
    let accentColor: Color

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                .foregroundStyle(accentColor)

            Text(message)
                .font(.avenirNext(size: GameFonts.calloutSize, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach(buttons, id: \.self) { label in
                    Text(label)
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ValidMovesInfoView()
}
