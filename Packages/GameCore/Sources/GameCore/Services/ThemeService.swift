import Foundation

// MARK: - Theme Model
public struct GameTheme: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let primaryColor: String // Hex color
    public let secondaryColor: String
    public let backgroundImageName: String?
    public let isLocked: Bool
    public let unlockCost: Int?
    
    public init(
        id: String,
        name: String,
        primaryColor: String,
        secondaryColor: String,
        backgroundImageName: String? = nil,
        isLocked: Bool = false,
        unlockCost: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.backgroundImageName = backgroundImageName
        self.isLocked = isLocked
        self.unlockCost = unlockCost
    }
}

// MARK: - Protocol
public protocol ThemeService: Sendable {
    func availableThemes() async -> [GameTheme]
    func currentTheme() async -> GameTheme
    func apply(theme: GameTheme) async throws
    func unlock(theme: GameTheme) async throws -> Bool
    func isUnlocked(themeId: String) async -> Bool
}

// MARK: - Mock Implementation
public actor ThemeServiceMock: ThemeService {
    private var themes: [GameTheme]
    private var currentThemeId: String
    private var unlockedThemeIds: Set<String>
    
    public init() {
        self.themes = Self.defaultThemes()
        self.currentThemeId = "beach"
        self.unlockedThemeIds = ["beach", "aqua", "desert", "jungle"]
    }
    
    public func availableThemes() async -> [GameTheme] {
        return themes
    }
    
    public func currentTheme() async -> GameTheme {
        return themes.first { $0.id == currentThemeId } ?? themes[0]
    }
    
    public func apply(theme: GameTheme) async throws {
        guard unlockedThemeIds.contains(theme.id) else {
            throw ThemeError.themeLocked
        }
        currentThemeId = theme.id
    }
    
    public func unlock(theme: GameTheme) async throws -> Bool {
        guard !unlockedThemeIds.contains(theme.id) else {
            return true // Already unlocked
        }
        
        // Preview/test service: production purchases route through StoreKit.
        unlockedThemeIds.insert(theme.id)
        return true
    }
    
    public func isUnlocked(themeId: String) async -> Bool {
        return unlockedThemeIds.contains(themeId)
    }
    
    private static func defaultThemes() -> [GameTheme] {
        return [
            GameTheme(
                id: "beach",
                name: "Beach",
                primaryColor: "#FFA500",
                secondaryColor: "#FFD700",
                backgroundImageName: "beach_bg"
            ),
            GameTheme(
                id: "aqua",
                name: "Aqua",
                primaryColor: "#00CED1",
                secondaryColor: "#4169E1",
                backgroundImageName: "aqua_bg"
            ),
            GameTheme(
                id: "desert",
                name: "Desert",
                primaryColor: "#DEB887",
                secondaryColor: "#D2691E",
                backgroundImageName: "desert_bg"
            ),
            GameTheme(
                id: "jungle",
                name: "Jungle",
                primaryColor: "#228B22",
                secondaryColor: "#32CD32",
                backgroundImageName: "jungle_bg"
            ),
            GameTheme(
                id: "space",
                name: "Space",
                primaryColor: "#191970",
                secondaryColor: "#4B0082",
                backgroundImageName: "space_bg",
                isLocked: true,
                unlockCost: 500
            ),
            GameTheme(
                id: "neon",
                name: "Neon",
                primaryColor: "#FF1493",
                secondaryColor: "#00FFFF",
                backgroundImageName: "neon_bg",
                isLocked: true,
                unlockCost: 1000
            )
        ]
    }
}

public enum ThemeError: Error {
    case themeLocked
    case insufficientGems
    case themeNotFound
}

// MARK: - Live Implementation
public actor LiveThemeService: ThemeService {
    private let defaults = UserDefaults.standard
    private let themes: [GameTheme]
    
    public init() {
        self.themes = LiveThemeService.loadThemes()
    }
    
    public func availableThemes() async -> [GameTheme] {
        return themes
    }
    
    public func currentTheme() async -> GameTheme {
        let themeId = defaults.string(forKey: "currentThemeId") ?? "beach"
        return themes.first { $0.id == themeId } ?? themes[0]
    }
    
    public func apply(theme: GameTheme) async throws {
        guard await isUnlocked(themeId: theme.id) else {
            throw ThemeError.themeLocked
        }
        defaults.set(theme.id, forKey: "currentThemeId")
    }
    
    public func unlock(theme: GameTheme) async throws -> Bool {
        let unlockedKey = "theme_unlocked_\(theme.id)"
        
        guard !defaults.bool(forKey: unlockedKey) else {
            return true // Already unlocked
        }
        
        if let cost = theme.unlockCost {
            let currentGems = defaults.integer(forKey: "coins")
            guard currentGems >= cost else {
                throw ThemeError.insufficientGems
            }
            defaults.set(currentGems - cost, forKey: "coins")
        }
        
        defaults.set(true, forKey: unlockedKey)
        return true
    }
    
    public func isUnlocked(themeId: String) async -> Bool {
        // Default themes are always unlocked
        let defaultUnlocked = ["beach", "aqua", "desert", "jungle"]
        if defaultUnlocked.contains(themeId) {
            return true
        }
        
        let unlockedKey = "theme_unlocked_\(themeId)"
        return defaults.bool(forKey: unlockedKey)
    }
    
    private static func loadThemes() -> [GameTheme] {
        // In production, this could load from a JSON file or remote config
        return [
            GameTheme(id: "beach", name: "Beach", primaryColor: "#FFA500", secondaryColor: "#FFD700"),
            GameTheme(id: "aqua", name: "Aqua", primaryColor: "#00CED1", secondaryColor: "#4169E1"),
            GameTheme(id: "desert", name: "Desert", primaryColor: "#DEB887", secondaryColor: "#D2691E"),
            GameTheme(id: "jungle", name: "Jungle", primaryColor: "#228B22", secondaryColor: "#32CD32"),
            GameTheme(id: "space", name: "Space", primaryColor: "#191970", secondaryColor: "#4B0082", isLocked: true, unlockCost: 500),
            GameTheme(id: "neon", name: "Neon", primaryColor: "#FF1493", secondaryColor: "#00FFFF", isLocked: true, unlockCost: 1000),
            GameTheme(id: "retro", name: "Retro", primaryColor: "#8B4513", secondaryColor: "#FF8C00", isLocked: true, unlockCost: 750),
            GameTheme(id: "ice", name: "Ice", primaryColor: "#B0E0E6", secondaryColor: "#87CEEB", isLocked: true, unlockCost: 600)
        ]
    }
}
