import SwiftUI
import GameApp

public struct PerksInfoView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Perks list
                VStack(spacing: 20) {
                    PerkRow(
                        assetName: "hammer",
                        iconColor: .orange,
                        title: "Break Any Tile On The Board"
                    )

                    PerkRow(
                        assetName: "swap",
                        iconColor: .green,
                        title: "Swap Any 2 Tiles With Each Other"
                    )

                    PerkRow(
                        assetName: "magnet",
                        iconColor: .purple,
                        title: "Merge Same Tiles On The Board"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)

                Spacer()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Perks")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Perk Row

private struct PerkRow: View {
    let assetName: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon using PNG asset
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [iconColor, iconColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .shadow(color: iconColor.opacity(0.3), radius: 4, y: 2)

            // Title
            Text(title)
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

#Preview {
    PerksInfoView()
}
