import SwiftUI

struct PillButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    @Environment(\.gameStore) private var gameStore
    @AppStorage("selectedPlayButtonColorId") private var selectedPlayButtonColorId: String = "green"

    private var buttonColor: Color {
        PlayButtonColor.color(for: selectedPlayButtonColorId)
    }

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
                .foregroundStyle(.white)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [buttonColor, buttonColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: buttonColor.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
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
                .foregroundStyle(.white)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [buttonColor, buttonColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: buttonColor.opacity(0.3), radius: 8, y: 4)
            }
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .accessibilityLabel(title)
        }
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
