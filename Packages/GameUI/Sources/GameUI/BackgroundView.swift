import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct BackgroundView: View {
    var body: some View {
        // Solid very-dark blue background as specified for Glass Preview feature
        // Use #020617 (sRGB 2, 6, 23) so it reads as "almost black with a blue tint"
        Color(hex: "020617")
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
