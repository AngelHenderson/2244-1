import SwiftUI

// MARK: - Avenir Next Font System

/// Custom font definitions using Avenir Next
public enum GameFonts {
    /// Font family name
    public static let fontFamily = "Avenir Next"

    // MARK: - Font Names by Weight
    private static let ultraLight = "AvenirNext-UltraLight"
    private static let regular = "AvenirNext-Regular"
    private static let medium = "AvenirNext-Medium"
    private static let demiBold = "AvenirNext-DemiBold"
    private static let bold = "AvenirNext-Bold"
    private static let heavy = "AvenirNext-Heavy"

    /// Returns the appropriate Avenir Next font name for a given weight
    public static func fontName(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light:
            return ultraLight
        case .regular:
            return regular
        case .medium:
            return medium
        case .semibold:
            return demiBold
        case .bold:
            return bold
        case .heavy, .black:
            return heavy
        default:
            return regular
        }
    }

    // MARK: - Preset Sizes (matching iOS Dynamic Type)
    public static let largeTitleSize: CGFloat = 34
    public static let title1Size: CGFloat = 28
    public static let title2Size: CGFloat = 22
    public static let title3Size: CGFloat = 20
    public static let headlineSize: CGFloat = 17
    public static let bodySize: CGFloat = 17
    public static let calloutSize: CGFloat = 16
    public static let subheadlineSize: CGFloat = 15
    public static let footnoteSize: CGFloat = 13
    public static let caption1Size: CGFloat = 12
    public static let caption2Size: CGFloat = 11
}

// MARK: - Font Extension for Avenir Next

public extension Font {
    /// Creates an Avenir Next font with the specified size and weight
    static func avenirNext(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let fontName = GameFonts.fontName(for: weight)
        return Font.custom(fontName, size: size)
    }

    /// Creates an Avenir Next font that scales with Dynamic Type
    static func avenirNext(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let fontName = GameFonts.fontName(for: weight)
        return Font.custom(fontName, size: size(for: style), relativeTo: style)
    }

    /// Returns the base size for a text style
    private static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return GameFonts.largeTitleSize
        case .title: return GameFonts.title1Size
        case .title2: return GameFonts.title2Size
        case .title3: return GameFonts.title3Size
        case .headline: return GameFonts.headlineSize
        case .body: return GameFonts.bodySize
        case .callout: return GameFonts.calloutSize
        case .subheadline: return GameFonts.subheadlineSize
        case .footnote: return GameFonts.footnoteSize
        case .caption: return GameFonts.caption1Size
        case .caption2: return GameFonts.caption2Size
        @unknown default: return GameFonts.bodySize
        }
    }

    // MARK: - Convenience Methods

    /// Large title in Avenir Next
    static var avenirLargeTitle: Font {
        .avenirNext(size: GameFonts.largeTitleSize, weight: .bold)
    }

    /// Title in Avenir Next
    static var avenirTitle: Font {
        .avenirNext(size: GameFonts.title1Size, weight: .bold)
    }

    /// Title 2 in Avenir Next
    static var avenirTitle2: Font {
        .avenirNext(size: GameFonts.title2Size, weight: .bold)
    }

    /// Title 3 in Avenir Next
    static var avenirTitle3: Font {
        .avenirNext(size: GameFonts.title3Size, weight: .semibold)
    }

    /// Headline in Avenir Next
    static var avenirHeadline: Font {
        .avenirNext(size: GameFonts.headlineSize, weight: .semibold)
    }

    /// Body in Avenir Next
    static var avenirBody: Font {
        .avenirNext(size: GameFonts.bodySize, weight: .regular)
    }

    /// Callout in Avenir Next
    static var avenirCallout: Font {
        .avenirNext(size: GameFonts.calloutSize, weight: .regular)
    }

    /// Subheadline in Avenir Next
    static var avenirSubheadline: Font {
        .avenirNext(size: GameFonts.subheadlineSize, weight: .regular)
    }

    /// Footnote in Avenir Next
    static var avenirFootnote: Font {
        .avenirNext(size: GameFonts.footnoteSize, weight: .regular)
    }

    /// Caption in Avenir Next
    static var avenirCaption: Font {
        .avenirNext(size: GameFonts.caption1Size, weight: .regular)
    }

    /// Caption 2 in Avenir Next
    static var avenirCaption2: Font {
        .avenirNext(size: GameFonts.caption2Size, weight: .regular)
    }
}

// MARK: - View Modifier for Global Font

/// A view modifier that applies Avenir Next font throughout the view hierarchy
public struct AvenirNextFontModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .environment(\.font, .avenirBody)
    }
}

public extension View {
    /// Applies Avenir Next font styling to this view
    func avenirNextStyle() -> some View {
        modifier(AvenirNextFontModifier())
    }
}
