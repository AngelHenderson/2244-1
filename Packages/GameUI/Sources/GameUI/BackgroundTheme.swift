import SwiftUI
import Foundation

// MARK: - Background Theme System

public struct BackgroundTheme: Sendable {
    public enum ScaleMode: String, Sendable {
        case fill   // Scale to fill and crop (default for widescreen images)
        case fit    // Scale to fit entirely (shows full image, may have bars)
    }
    
    public let id: String
    public let name: String
    public let imageName: String
    public let category: String
    public let overlayOpacity: Double // For text readability
    public let scaleMode: ScaleMode
    
    public init(
        id: String,
        name: String,
        imageName: String,
        category: String,
        overlayOpacity: Double = 0.0,
        scaleMode: ScaleMode = .fill
    ) {
        self.id = id
        self.name = name
        self.imageName = imageName
        self.category = category
        self.overlayOpacity = overlayOpacity
        self.scaleMode = scaleMode
    }
}

public struct BackgroundThemeRegistry: Sendable {
    private var themesById: [String: BackgroundTheme]
    public var defaultTheme: BackgroundTheme
    
    public init(themes: [BackgroundTheme], defaultId: String) {
        var mapping: [String: BackgroundTheme] = [:]
        for theme in themes {
            mapping[theme.id] = theme
        }
        self.themesById = mapping
        self.defaultTheme = mapping[defaultId] ?? themes.first!
    }
    
    public func theme(for id: String?) -> BackgroundTheme {
        guard let id, let theme = themesById[id] else {
            return defaultTheme
        }
        return theme
    }
    
    public func allThemes() -> [BackgroundTheme] {
        Array(themesById.values).sorted { $0.category == $1.category ? $0.name < $1.name : $0.category < $1.category }
    }
    
    public func themesByCategory() -> [String: [BackgroundTheme]] {
        Dictionary(grouping: allThemes(), by: { $0.category })
    }
}

// MARK: - Default Registry

extension BackgroundThemeRegistry {
    public static var Default: BackgroundThemeRegistry {
        let themes = [
            // City themes
            BackgroundTheme(
                id: "city_1",
                name: "City Dawn",
                imageName: "city_1_light",
                category: "City",
                overlayOpacity: 0.1
            ),
            BackgroundTheme(
                id: "city_2",
                name: "City Night",
                imageName: "city_2_light",
                category: "City",
                overlayOpacity: 0.2
            ),
            
            // Desert themes
            BackgroundTheme(
                id: "desert_1",
                name: "Desert Dunes",
                imageName: "desert_1_light",
                category: "Desert",
                overlayOpacity: 0.05
            ),
            BackgroundTheme(
                id: "desert_2",
                name: "Desert Oasis",
                imageName: "desert_2_light",
                category: "Desert",
                overlayOpacity: 0.05
            ),
            BackgroundTheme(
                id: "desert_3",
                name: "Desert Sunset",
                imageName: "desert_3_light",
                category: "Desert",
                overlayOpacity: 0.1
            ),
            
            // Jungle themes
            BackgroundTheme(
                id: "jungle_1",
                name: "Jungle Canopy",
                imageName: "jungle_1_light",
                category: "Jungle",
                overlayOpacity: 0.15
            ),
            BackgroundTheme(
                id: "jungle_2",
                name: "Jungle Mist",
                imageName: "jungle_2_light",
                category: "Jungle",
                overlayOpacity: 0.1
            ),
            
            // Snow themes
            BackgroundTheme(
                id: "snow_1",
                name: "Winter Morning",
                imageName: "snow_1_light",
                category: "Snow",
                overlayOpacity: 0.0
            ),
            BackgroundTheme(
                id: "snow_2",
                name: "Aurora Night",
                imageName: "snow_2_light",
                category: "Snow",
                overlayOpacity: 0.15
            ),
            
            // Underwater themes
            BackgroundTheme(
                id: "underwater_1",
                name: "Ocean Depths",
                imageName: "underwater_1_light",
                category: "Underwater",
                overlayOpacity: 0.2
            ),
            BackgroundTheme(
                id: "underwater_2",
                name: "Coral Reef",
                imageName: "underwater_2_light",
                category: "Underwater",
                overlayOpacity: 0.1
            ),
            BackgroundTheme(
                id: "underwater_3",
                name: "Deep Sea",
                imageName: "underwater_3_light",
                category: "Underwater",
                overlayOpacity: 0.25
            ),
            
            // Default solid color theme
            BackgroundTheme(
                id: "solid_default",
                name: "Classic",
                imageName: "",
                category: "Solid",
                overlayOpacity: 0.0
            )
        ]
        
        return BackgroundThemeRegistry(
            themes: themes,
            defaultId: "city_1"
        )
    }
}

// MARK: - Background View Component

public struct ThemedBackground: View {
    let theme: BackgroundTheme
    
    public init(theme: BackgroundTheme) {
        self.theme = theme
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if theme.imageName.isEmpty {
                    // Solid color background
                    LinearGradient(
                        colors: [
                            Color(hex: "1a1a2e"),
                            Color(hex: "16213e")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                } else {
                    // Image background - scale to fill and clip overflow
                    Image(theme.imageName)
                        .resizable()
                        .scaledToFill() // This ensures the image fills the entire view
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()  // Clips any overflow on the sides
                        .ignoresSafeArea()
                    
                    // Overlay for better text readability if needed
                    if theme.overlayOpacity > 0 {
                        Color.black.opacity(theme.overlayOpacity)
                            .ignoresSafeArea()
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()  // Ensure the GeometryReader itself extends to edges
    }
}
