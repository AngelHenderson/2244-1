import SwiftUI

public struct CurrentThemeKey: EnvironmentKey {
    nonisolated public static var defaultValue: ThemeDescriptor? {
        nil
    }
}

public extension EnvironmentValues {
    var currentTheme: ThemeDescriptor? {
        get { self[CurrentThemeKey.self] }
        set { self[CurrentThemeKey.self] = newValue }
    }
}