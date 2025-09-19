# Data Model: Create 2244 - Initial Playable Shell

**Date**: 2025-01-16  
**Feature**: 003-create-2244-initial

## Core Entities

### Profile
Primary entity representing the single default user profile.

```swift
struct Profile: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var powerUpInventory: [PowerUpType: Int]
    var coins: Int
    var gems: Int
    var achievements: Set<String>
    var statistics: PlayerStatistics
    var settings: ProfileSettings
    var unlockedThemes: Set<ThemeID>
    var currentTheme: ThemeID
    var leaderboardRank: Int?
    var currentTileProgress: Int // e.g., 1024
    var highestTileReached: Int // e.g., 4096
    var dailySpinAvailable: Bool
    var lastDailySpinAt: Date?
    var watchedAdsToday: Int
    let createdAt: Date
    var lastPlayedAt: Date
}

struct ProfileSettings: Codable {
    var musicVolume: Float // 0.0 - 1.0
    var effectsVolume: Float // 0.0 - 1.0
    var hapticsEnabled: Bool
    var reducedMotion: Bool
    var colorBlindMode: ColorBlindMode?
}

struct PlayerStatistics: Codable {
    var gamesPlayed: Int
    var totalScore: Int
    var highestScore: Int
    var highestTile: Int
    var totalChains: Int
    var longestChain: Int
    var powerUpsUsed: [PowerUpType: Int]
    var totalPlayTime: TimeInterval
}

enum PowerUpType: String, Codable, CaseIterable {
    case hammer
    case swap
    case magnet
    case shuffle
    case undo
    case double
}

enum ThemeID: String, Codable, CaseIterable {
    case classic
    case minimal
    case retro
    case cyberpunk // Premium
    case lofi // Premium
    case orchestral // Premium
}

enum ColorBlindMode: String, Codable {
    case protanopia
    case deuteranopia
    case tritanopia
}
```

### GameSession
Active game state for any mode.

```swift
struct GameSession: Codable {
    let id: UUID
    let mode: GameMode
    var board: Board
    var score: Int
    var moves: Int
    var chains: Int
    var powerUpsUsed: [PowerUpType: Int]
    var activeTasks: [ProjectTask]
    var taskProgress: [String: TaskProgress]
    let seed: UInt64
    let startedAt: Date
    var lastMoveAt: Date?
    var isPaused: Bool
}

struct Board: Codable {
    let width: Int = 5
    let height: Int = 8
    var tiles: [[Tile?]]
    
    init() {
        tiles = Array(repeating: Array(repeating: nil, count: width), count: height)
    }
}

struct Tile: Codable, Equatable {
    let value: Int
    let id: UUID
    var isLocked: Bool = false
    var specialType: SpecialTileType?
}

enum SpecialTileType: String, Codable {
    case gift
    case bomb
    case multiplier
}

enum GameMode: String, Codable {
    case classic
    case daily
    case journey
    case custom
}
```

### MusicTheme
Audio and haptic theme definition.

```swift
struct MusicTheme: Identifiable {
    let id: ThemeID
    let displayName: String
    let description: String
    let isPremium: Bool
    let backgroundMusicFile: String
    let soundEffects: [SoundEffectType: String]
    let hapticPatterns: [HapticType: HapticPattern]
    let accentColor: Color
    let secondaryColor: Color
}

enum SoundEffectType: String, CaseIterable {
    case tileSelect
    case tileMerge
    case chainComplete
    case invalidMove
    case powerUpActivate
    case gameOver
    case newHighScore
    // UI sounds
    case buttonTap
    case swipeGesture
    case menuOpen
    case menuClose
    case toggleSwitch
    case sliderChange
}

enum HapticType: String, CaseIterable {
    case selection
    case impact
    case success
    case warning
    case error
}

struct HapticPattern: Codable {
    let intensity: Float
    let sharpness: Float
    let duration: TimeInterval
    let pattern: [HapticEvent]
}

struct HapticEvent: Codable {
    let time: TimeInterval
    let intensity: Float
    let sharpness: Float
}
```

### ProjectTask
Pre-populated tasks for sample game modes.

```swift
struct ProjectTask: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let projectID: ProjectID
    let category: TaskCategory
    let requirement: TaskRequirement?
    let reward: TaskReward?
    let sortOrder: Int
}

enum ProjectID: String, Codable {
    case classicDemo
    case dailyChallenge
    case journeyStage1
    case journeyStage2
}

enum TaskCategory: String, Codable {
    case tutorial
    case score
    case chain
    case powerUp
    case exploration
    case mastery
}

enum TaskRequirement: Codable {
    case score(minimum: Int)
    case chain(length: Int)
    case tile(value: Int)
    case powerUpUse(type: PowerUpType)
    case moves(maximum: Int)
    case time(maximum: TimeInterval)
    case combo(count: Int)
}

struct TaskReward: Codable {
    var coins: Int?
    var gems: Int?
    var powerUps: [PowerUpType: Int]?
    var achievement: String?
}

struct TaskProgress: Codable {
    let taskID: String
    var status: TaskStatus
    var currentValue: Int?
    var startedAt: Date?
    var completedAt: Date?
}

enum TaskStatus: String, Codable {
    case notStarted
    case inProgress
    case completed
}
```

### Challenge
Custom challenge definitions.

```swift
struct Challenge: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let creatorID: UUID // Profile ID
    let targetScore: Int
    let moveLimit: Int?
    let timeLimit: TimeInterval?
    let allowedTiles: Set<Int>
    let startingBoard: Board?
    let powerUpsAllowed: Set<PowerUpType>
    let difficulty: DifficultyEstimate
    let createdAt: Date
    var playCount: Int
    var completionCount: Int
    var averageScore: Int?
    var comments: [ChallengeComment]
}

struct DifficultyEstimate: Codable {
    let rating: Int // 1-5
    let factors: [String] // ["Limited moves", "High target", etc.]
}

struct ChallengeComment: Codable, Identifiable {
    let id: UUID
    let authorID: UUID
    let content: String
    let createdAt: Date
    var isEditable: Bool // Only true for own comments
}
```

### Spin Wheel & Rewards

```swift
struct SpinWheelReward: Codable {
    let id: String
    let type: RewardType
    let amount: Int
    let weight: Int // Probability weight
}

enum RewardType: String, Codable {
    case coins
    case gems
    case powerUp
    case theme
    case adFree
}

struct DailySpinResult: Codable {
    let reward: SpinWheelReward
    let timestamp: Date
    let isJackpot: Bool
}
```

### Time-Limited Offers

```swift
struct TimeLimitedOffer: Codable, Identifiable {
    let id: UUID
    let type: OfferType
    let title: String
    let description: String
    let originalPrice: Decimal
    let discountedPrice: Decimal
    let discountPercentage: Int
    let expiresAt: Date
    let items: [OfferItem]
    var isPurchased: Bool
}

enum OfferType: String, Codable {
    case saleOffer
    case bestOffer
    case dailyDeal
    case bundle
}

struct OfferItem: Codable {
    let type: String // "coins", "gems", "powerUp", etc.
    let itemId: String?
    let quantity: Int
}
```

### Leaderboard Integration

```swift
struct LeaderboardEntry: Codable {
    let playerId: UUID
    let displayName: String
    let score: Int
    let rank: Int
    let timestamp: Date
    let countryCode: String?
}

struct LeaderboardData: Codable {
    var globalRank: Int?
    var weeklyRank: Int?
    var dailyRank: Int?
    var friendsRank: Int?
    var topPlayers: [LeaderboardEntry]
    var nearbyPlayers: [LeaderboardEntry]
}
```

### Ad Integration

```swift
struct AdConfiguration: Codable {
    var bannerEnabled: Bool
    var bannerPosition: BannerPosition
    var rewardedVideoEnabled: Bool
    var interstitialEnabled: Bool
    var dailyAdLimit: Int
    var rewardAmount: Int
}

enum BannerPosition: String, Codable {
    case top
    case bottom
}

struct AdReward: Codable {
    let type: RewardType
    let amount: Int
    let watchedAt: Date
}
```

### In-App Purchase Products

```swift
struct IAPProduct: Identifiable {
    let id: String // StoreKit product ID
    let type: IAPProductType
    let displayName: String
    let description: String
    let price: Decimal?
    var isPurchased: Bool
    var isAvailable: Bool
}

enum IAPProductType: String, Codable {
    case theme // Non-consumable
    case adFree // Non-consumable
    case coinPack // Consumable
    case gemPack // Consumable
}

struct PurchaseTransaction: Codable {
    let id: String
    let productID: String
    let purchaseDate: Date
    let expirationDate: Date?
    let isActive: Bool
}
```

## State Management

### GameStore Updates
```swift
@Observable
@MainActor
final class GameStore {
    var profile: Profile
    var currentSession: GameSession?
    var availableThemes: [MusicTheme]
    var products: [IAPProduct]
    var isAudioLoading: Bool = false
    var currentAudioTheme: ThemeID
}
```

### ProfileStore (New)
```swift
@Observable
@MainActor
final class ProfileStore {
    var profile: Profile
    var challenges: [Challenge]
    var taskProgress: [String: TaskProgress]
    
    func consumePowerUp(_ type: PowerUpType) -> Bool
    func addCoins(_ amount: Int)
    func unlockTheme(_ themeID: ThemeID)
    func updateTaskProgress(_ taskID: String, value: Int)
}
```

## Validation Rules

### Profile Validation
- Display name: 1-20 characters
- Coins: Non-negative integer
- Gems: Non-negative integer
- Power-up inventory: Non-negative counts
- Volume settings: 0.0 to 1.0 range

### Game Session Validation
- Board dimensions: Exactly 5×8
- Tile values: Powers of 2 (2, 4, 8, 16, ...)
- Score: Non-negative, increases only
- Moves: Non-negative, increases only
- Seed: Valid UInt64 for deterministic replay

### Challenge Validation
- Name: 1-50 characters
- Target score: 100 to 1,000,000
- Move limit: 10 to 9999 (optional)
- Time limit: 30s to 1 hour (optional)
- At least 2 tile values allowed
- Comments: 1-500 characters

### Task Validation
- Task IDs unique within project
- Status transitions: notStarted → inProgress → completed
- Cannot transition backward
- Completed tasks remain immutable

## Persistence Strategy

### UserDefaults Keys
```swift
enum UserDefaultsKey: String {
    case profileData = "com.game2244.profile"
    case currentSessionData = "com.game2244.currentSession"
    case taskProgressData = "com.game2244.taskProgress"
    case purchasedProducts = "com.game2244.purchases"
    case audioSettings = "com.game2244.audio"
}
```

### File Storage
- Challenges: `Documents/Challenges/[UUID].json`
- Replays: `Documents/Replays/[UUID].json`
- Custom themes: `Documents/Themes/[name].theme`

### Migration Strategy
Version migrations handled through Codable's decoding with defaults:
- New fields get sensible defaults
- Removed fields ignored during decoding
- Version number in each saved file for future migrations

---

## Summary

The data model provides:
1. Complete profile management with settings and statistics
2. Full game session tracking with deterministic replay support
3. Comprehensive audio theme system with haptics
4. Task and challenge systems for engagement
5. IAP product management for monetization
6. Proper validation rules for data integrity
7. Clear persistence strategy using UserDefaults and file storage

All entities are Codable for easy serialization and follow Swift 6 concurrency guidelines with proper actor isolation.