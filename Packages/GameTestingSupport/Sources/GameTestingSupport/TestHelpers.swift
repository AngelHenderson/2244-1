import Foundation
import GameCore

public struct TestHelpers {
    public static func createTestBoard(width: Int = 5, height: Int = 6) -> Board {
        Board(width: width, height: height)
    }
    
    public static func createTestConfig(seed: UInt64 = 12345) -> GameConfig {
        GameConfig(seed: seed)
    }
}