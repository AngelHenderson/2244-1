import SwiftUI

struct TileBadge: View {
    let value: Int
    let style: Style

    enum Style { case primary, secondary, locked }

    var body: some View {
        let size: CGFloat = style == .primary ? 140 : 80
        VStack {
            Text("\(value)")
                .font(.system(size: style == .primary ? 44 : 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    if style == .locked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.white.opacity(0.95))
                            .font(.title2)
                    }
                }
        }
        .accessibilityLabel(accessibility)
    }

    private var background: some ShapeStyle {
        switch style {
        case .primary: 
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary: 
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .locked: 
            return LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var accessibility: String {
        switch style {
        case .primary: "Highest tile \(value)"
        case .secondary: "Milestone \(value)"
        case .locked: "Locked milestone \(value)"
        }
    }
}
