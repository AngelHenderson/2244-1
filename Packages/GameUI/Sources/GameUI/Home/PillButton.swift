import SwiftUI

struct PillButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void
    
    @Environment(\.gameStore) private var gameStore

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Button(action: action) {
                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .imageScale(.large)
                    }
                    Text(title)
                        .font(.title3.weight(.bold))
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .tint(dynamicGlassTint)
            .accessibilityLabel(title)
        } else {
            Button(action: action) {
                HStack(spacing: 12) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .imageScale(.large)
                    }
                    Text(title)
                        .font(.title2.weight(.bold))
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
            }
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityLabel(title)
        }
    }
    
    /// Dynamically compute glass tint based on current board state
    private var dynamicGlassTint: Color {
        // Use the highest tile from game state as the tint color
        let highestValue = gameStore.state.highestTile

        // Use Theme system to get the color for the highest tile
        return Theme.color(for: highestValue)
    }
}
 
#Preview("PillButton Variants", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        PillButton(title: "Continue", icon: "arrow.right") {
            print("Continue tapped")
        }
        PillButton(title: "Get Started") {
            print("Get Started tapped")
        }
        PillButton(title: "Download", icon: "square.and.arrow.down") {
            print("Download tapped")
        }
    }
    .padding()
}
