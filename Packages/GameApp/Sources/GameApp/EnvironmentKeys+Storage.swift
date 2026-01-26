import SwiftUI
import GameCore

public struct StorageServiceKey: EnvironmentKey {
    nonisolated public static var defaultValue: any StorageServiceProtocol {
        UserDefaultsStorageService()
    }
}

public extension EnvironmentValues {
    var storage: any StorageServiceProtocol {
        get { self[StorageServiceKey.self] }
        set { self[StorageServiceKey.self] = newValue }
    }
}

