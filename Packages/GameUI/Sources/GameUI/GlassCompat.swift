import SwiftUI

// MARK: - Liquid Glass (iOS 26) with material fallback
struct GlassOrMaterialBackground: ViewModifier {
    var cornerRadius: CGFloat = 14
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
//                .glassEffect()
//                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
//                .background(
//                    .regularMaterial,
//                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
//                )
//                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension View {
    func glassOrMaterialBackground(cornerRadius: CGFloat = 8) -> some View {
        modifier(GlassOrMaterialBackground(cornerRadius: cornerRadius))
    }
}


