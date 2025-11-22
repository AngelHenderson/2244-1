import SwiftUI
import GameCore

struct MagnetAnimationModel: Identifiable, Equatable {
    let id = UUID()
    let value: Int
    let start: Position
    let target: Position
    var progress: CGFloat
}

