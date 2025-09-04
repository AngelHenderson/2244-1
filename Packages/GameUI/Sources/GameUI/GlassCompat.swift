import SwiftUI

// MARK: - Liquid Glass (iOS 26) with material fallback
struct GlassOrMaterialBackground: ViewModifier {
    var cornerRadius: CGFloat = 14
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension View {
    func glassOrMaterialBackground(cornerRadius: CGFloat = 8) -> some View {
        modifier(GlassOrMaterialBackground(cornerRadius: cornerRadius))
    }
}


