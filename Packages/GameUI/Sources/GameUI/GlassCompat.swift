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


// MARK: - Glass Background Modifiers

extension View {
    /// Applies a glass background effect on supported platforms, falling back to ultraThinMaterial.
    /// - Parameter cornerRadius: The corner radius for the background. Default is 0 (rectangular).
    @ViewBuilder
    func glassBackground(cornerRadius: CGFloat = 0) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
    
    /// Applies a glass background effect clipped to a specific shape on supported platforms,
    /// falling back to ultraThinMaterial.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
    
    // Deprecated: Migrating to glassBackground
    func glassOrMaterialBackground(cornerRadius: CGFloat = 8) -> some View {
        glassBackground(cornerRadius: cornerRadius)
    }
}


