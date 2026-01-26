import SwiftUI
import GameCore
import GameServices

public struct AudioServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: any AudioServiceProtocol {
        DefaultAudioService()
    }
}

public extension EnvironmentValues {
    var audio: any AudioServiceProtocol {
        get { self[AudioServiceKey.self] }
        set { self[AudioServiceKey.self] = newValue }
    }
}


