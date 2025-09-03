import SwiftUI
import GameServices

public struct RemoteConfigServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: any RemoteConfigServiceProtocol {
        DefaultRemoteConfigService()
    }
}

public extension EnvironmentValues {
    var remoteConfig: any RemoteConfigServiceProtocol {
        get { self[RemoteConfigServiceKey.self] }
        set { self[RemoteConfigServiceKey.self] = newValue }
    }
}


