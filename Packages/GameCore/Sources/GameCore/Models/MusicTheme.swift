import Foundation

public enum MusicTheme: String, CaseIterable, Codable, Sendable {
    case classic
    case minimal
    case retro
    case cyberpunk
    case lofi
    case orchestral

    public var displayName: String {
        switch self {
        case .classic:
            return "Classic"
        case .minimal:
            return "Minimal"
        case .retro:
            return "Retro"
        case .cyberpunk:
            return "Cyberpunk"
        case .lofi:
            return "Lo-Fi"
        case .orchestral:
            return "Orchestral"
        }
    }

    public var description: String {
        switch self {
        case .classic:
            return "The original 2244 soundtrack"
        case .minimal:
            return "Clean and focused ambient sounds"
        case .retro:
            return "8-bit nostalgia vibes"
        case .cyberpunk:
            return "Futuristic electronic beats"
        case .lofi:
            return "Relaxing lo-fi hip hop"
        case .orchestral:
            return "Epic cinematic experience"
        }
    }

    public var isPremium: Bool {
        switch self {
        case .classic, .minimal, .retro:
            return false
        case .cyberpunk, .lofi, .orchestral:
            return true
        }
    }

    public var iapProductId: String? {
        switch self {
        case .cyberpunk:
            return "com.game2244.theme.cyberpunk"
        case .lofi:
            return "com.game2244.theme.lofi"
        case .orchestral:
            return "com.game2244.theme.orchestral"
        default:
            return nil
        }
    }

    public var assetName: String {
        return "music_\(rawValue)"
    }

    public var bpm: Int {
        switch self {
        case .classic:
            return 120
        case .minimal:
            return 90
        case .retro:
            return 140
        case .cyberpunk:
            return 128
        case .lofi:
            return 85
        case .orchestral:
            return 100
        }
    }

    public static var freeThemes: [MusicTheme] {
        return allCases.filter { !$0.isPremium }
    }

    public static var premiumThemes: [MusicTheme] {
        return allCases.filter { $0.isPremium }
    }
}