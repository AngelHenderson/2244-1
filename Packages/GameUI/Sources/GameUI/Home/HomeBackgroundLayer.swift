import SwiftUI

/// Shared background layer for the Home experience. Starts blurred and animates to clear
/// when the view appears, creating a polished reveal effect.
public struct HomeBackgroundLayer: View {
    private let theme: BackgroundTheme
    private let initialBlurRadius: Double
    private let animationDuration: Double

    public init(theme: BackgroundTheme, initialBlurRadius: Double = 24, animationDuration: Double = 0.8) {
        self.theme = theme
        self.initialBlurRadius = initialBlurRadius
        self.animationDuration = animationDuration
    }

    public var body: some View {
        Group {
            if theme.imageName.isEmpty {
                ThemedBackground(theme: theme)
            } else {
#if canImport(UIKit)
                HomeBackgroundImageView(
                    theme: theme,
                    initialBlurRadius: initialBlurRadius,
                    animationDuration: animationDuration
                )
#else
                ThemedBackground(theme: theme)
#endif
            }
        }
    }
}

#if canImport(UIKit)
private struct HomeBackgroundImageView: View {
    let theme: BackgroundTheme
    let initialBlurRadius: Double
    let animationDuration: Double

    @State private var currentBlur: Double
    @State private var hasAppeared = false

    init(theme: BackgroundTheme, initialBlurRadius: Double, animationDuration: Double) {
        self.theme = theme
        self.initialBlurRadius = initialBlurRadius
        self.animationDuration = animationDuration
        self._currentBlur = State(initialValue: initialBlurRadius)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image(theme.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: currentBlur)
                    .clipped()

                if theme.overlayOpacity > 0 {
                    Color.black.opacity(theme.overlayOpacity)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            withAnimation(.easeOut(duration: animationDuration)) {
                currentBlur = 0
            }
        }
    }
}

#endif
