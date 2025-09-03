import SwiftUI
import GameServices

public struct GameCenterServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: any GameCenterServiceProtocol {
        DefaultGameCenterService()
    }
}

public extension EnvironmentValues {
    var gameCenter: any GameCenterServiceProtocol {
        get { self[GameCenterServiceKey.self] }
        set { self[GameCenterServiceKey.self] = newValue }
    }
}




