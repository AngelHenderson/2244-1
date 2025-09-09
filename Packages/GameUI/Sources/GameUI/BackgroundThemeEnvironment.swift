import SwiftUI

// MARK: - Background Theme Environment Keys

private struct BackgroundThemeKey: EnvironmentKey {
    static let defaultValue = BackgroundTheme(
        id: "city_1",
        name: "City Dawn",
        imageName: "city_1_light",
        category: "City",
        overlayOpacity: 0.1,
        scaleMode: .fill
    )
}

private struct BackgroundThemeRegistryKey: EnvironmentKey {
    static let defaultValue = BackgroundThemeRegistry.Default
}

public extension EnvironmentValues {
    var backgroundTheme: BackgroundTheme {
        get { self[BackgroundThemeKey.self] }
        set { self[BackgroundThemeKey.self] = newValue }
    }
    
    var currentBackgroundTheme: BackgroundTheme {
        get { self[BackgroundThemeKey.self] }
        set { self[BackgroundThemeKey.self] = newValue }
    }
    
    var backgroundThemeRegistry: BackgroundThemeRegistry {
        get { self[BackgroundThemeRegistryKey.self] }
        set { self[BackgroundThemeRegistryKey.self] = newValue }
    }
}
