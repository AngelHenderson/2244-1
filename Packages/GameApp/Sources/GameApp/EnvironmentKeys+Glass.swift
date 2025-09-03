import SwiftUI

private struct UseGlassPreviewKey: EnvironmentKey {
    static let defaultValue: Bool = true // Enable by default
}

public extension EnvironmentValues {
    var useGlassPreview: Bool {
        get { self[UseGlassPreviewKey.self] }
        set { self[UseGlassPreviewKey.self] = newValue }
    }
}
