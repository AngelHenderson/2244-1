import SwiftUI
import GameCore

extension AchievementDef.Rewards.Entry.Kind {
    var assetName: String {
        switch self {
        case .gems: return "gem"
        case .spins: return "spinthewheel"
        case .hammers: return "hammer"
        case .magnets: return "magnet"
        case .swaps: return "swap"
        case .boost2x: return "boost2x"
        case .boost3x: return "boost3x"
        case .boost4x: return "boost4x"
        }
    }

    var iconName: String {
        switch self {
        case .gems: return "gem"
        case .spins: return "arrow.triangle.2.circlepath"
        case .hammers: return "hammer.fill"
        case .magnets: return "dot.radiowaves.left.and.right"
        case .swaps: return "arrow.2.squarepath"
        case .boost2x, .boost3x, .boost4x: return "bolt.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .gems: return .cyan
        case .spins: return .purple
        case .hammers: return .orange
        case .magnets: return .blue
        case .swaps: return .green
        case .boost2x: return .yellow
        case .boost3x: return .pink
        case .boost4x: return .red
        }
    }

    var displayName: String {
        switch self {
        case .gems: return "Gems"
        case .spins: return "Spins"
        case .hammers: return "Hammers"
        case .magnets: return "MegaMerges"
        case .swaps: return "Swaps"
        case .boost2x: return "2× Boost"
        case .boost3x: return "3× Boost"
        case .boost4x: return "4× Boost"
        }
    }

    var subtitle: String {
        switch self {
        case .gems: return "Currency"
        case .spins: return "Spin the Wheel"
        case .hammers: return "Break a tile"
        case .magnets: return "Mega merge"
        case .swaps: return "Swap two tiles"
        case .boost2x: return "Double points"
        case .boost3x: return "Triple points"
        case .boost4x: return "Quad points"
        }
    }

    var isMultiplier: Bool {
        switch self {
        case .boost2x, .boost3x, .boost4x:
            return true
        default:
            return false
        }
    }
}
