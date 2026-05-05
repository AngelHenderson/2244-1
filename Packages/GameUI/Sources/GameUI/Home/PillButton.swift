import SwiftUI

struct PillButton: View {
    let title: String
    var icon: String? = nil
    var metrics: HomeLayoutMetrics.PlayButtonMetrics = .fallback
    var action: () -> Void

    @Environment(\.gameStore) private var gameStore
    @AppStorage("selectedPlayButtonColorId") private var selectedPlayButtonColorId: String = "green"

    private var buttonColor: Color {
        PlayButtonColor.color(for: selectedPlayButtonColorId)
    }

    var body: some View {
        GeometryReader { geometry in
            Button(action: action) {
                HStack(spacing: max(10, metrics.iconSize * 0.36)) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: metrics.iconSize, weight: .bold))
                    }
                    Text(title)
                        .font(.system(size: metrics.fontSize, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .foregroundStyle(.white)
                .frame(
                    width: min(metrics.maxWidth, geometry.size.width - metrics.horizontalPadding * 2),
                    height: metrics.buttonHeight
                )
                .background(
                    LinearGradient(
                        colors: [buttonColor, buttonColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                )
                .shadow(color: buttonColor.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: metrics.containerHeight)
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
