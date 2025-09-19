import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

/// Shared background layer for the Home experience. Applies the Core Image blur once per
/// theme so that foreground state updates do not trigger expensive reprocessing.
public struct HomeBackgroundLayer: View {
    private let theme: BackgroundTheme
    private let blurRadius: Double

    public init(theme: BackgroundTheme, blurRadius: Double = 48) {
        self.theme = theme
        self.blurRadius = blurRadius
    }

    public var body: some View {
        Group {
            if theme.imageName.isEmpty {
                ThemedBackground(theme: theme)
            } else {
#if canImport(UIKit)
                HomeBackgroundImageView(theme: theme, blurRadius: blurRadius, renderer: BackgroundRenderer.shared)
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
    let blurRadius: Double
    let renderer: BackgroundRenderer

    @State private var renderedImage: Image?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backgroundContent
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                if theme.overlayOpacity > 0 {
                    Color.black.opacity(theme.overlayOpacity)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .task(id: theme.id) {
            renderedImage = await renderer.render(theme: theme, blurRadius: blurRadius)
        }
        .onAppear {
            if renderedImage == nil {
                Task { renderedImage = await renderer.render(theme: theme, blurRadius: blurRadius) }
            }
        }
    }

    @ViewBuilder
    private var backgroundContent: some View {
        if let renderedImage {
            renderedImage
                .resizable()
                .scaledToFill()
        } else {
            Image(theme.imageName)
                .resizable()
                .scaledToFill()
        }
    }
}

final actor BackgroundRenderer {
    static let shared = BackgroundRenderer()
    private let context = CIContext()

    func render(theme: BackgroundTheme, blurRadius: Double) async -> Image? {
        guard !theme.imageName.isEmpty else { return nil }
        guard let sourceImage = loadPlatformImage(named: theme.imageName) else { return nil }

        let orientation = CGImagePropertyOrientation(rawValue: UInt32(sourceImage.imageOrientation.rawValue)) ?? .up
        guard let baseImage = CIImage(image: sourceImage)?.oriented(orientation) else { return nil }

        let filter = CIFilter.bokehBlur()
        filter.inputImage = baseImage
        filter.radius = Float(blurRadius)

        guard
            let filteredOutput = filter.outputImage?.cropped(to: baseImage.extent),
            let cgImage = context.createCGImage(filteredOutput, from: baseImage.extent)
        else {
            return nil
        }

        let rendered = UIImage(cgImage: cgImage)
        return Image(uiImage: rendered)
    }

    private func loadPlatformImage(named name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        if let image = UIImage(named: name, in: Bundle(for: GameUIBundleToken.self), with: nil) {
            return image
        }

        return UIImage(named: name, in: Bundle.main, with: nil)
    }
}

private final class GameUIBundleToken {}
#endif
