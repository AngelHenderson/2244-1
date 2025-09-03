import SwiftUI
import GameServices

public struct AnalyticsServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: any AnalyticsServiceProtocol {
        MainActor.assumeIsolated {
            DefaultAnalyticsService()
        }
    }
}

public extension EnvironmentValues {
    var analytics: any AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}


