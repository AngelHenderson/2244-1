import Foundation
import Observation

@MainActor
@Observable
public final class SpinWheelState {
    public enum MultiplierTier: String, CaseIterable, Codable, Hashable, Sendable {
        case twoX = "2x"
        case threeX = "3x"
        case fourX = "4x"
        
        public var displayName: String { rawValue.uppercased() }
        public var multiplierValue: Int {
            switch self {
            case .twoX: return 2
            case .threeX: return 3
            case .fourX: return 4
            }
        }
        public var duration: TimeInterval {
            switch self {
            case .twoX: return 24 * 60 * 60   // 24 hours
            case .threeX: return 18 * 60 * 60 // 18 hours
            case .fourX: return 12 * 60 * 60  // 12 hours
            }
        }
    }
    
    public enum SpinSource: Sendable {
        case scheduledSlot(Date)
        case bonus
    }
    
    public struct ActiveMultiplier: Codable, Hashable, Sendable {
        public let tier: MultiplierTier
        public var expiresAt: Date
        
        public var remainingDuration: TimeInterval {
            max(0, expiresAt.timeIntervalSinceNow)
        }
        
        public var isExpired: Bool {
            expiresAt <= Date()
        }
    }
    
    private struct DefaultsKeys {
        static let lastSlot = "spinWheel.lastSlot"
        static let bonusSpins = "spinWheel.bonusSpins"
        static let inventory = "spinWheel.inventory"
        static let activeMultiplier = "spinWheel.activeMultiplier"
    }
    
    private static let slotInterval: TimeInterval = 4 * 60 * 60 // 4 hours
    private static let slotsPerDay = 6
    
    private let defaults: UserDefaults
    
    public private(set) var lastConsumedSlot: Date?
    public private(set) var bonusSpins: Int
    public private(set) var inventory: [MultiplierTier: Int]
    public private(set) var activeMultiplier: ActiveMultiplier?
    
    public var hasActiveMultiplier: Bool {
        activeMultiplier != nil
    }
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let timestamp = defaults.object(forKey: DefaultsKeys.lastSlot) as? TimeInterval {
            lastConsumedSlot = Date(timeIntervalSince1970: timestamp)
        } else {
            lastConsumedSlot = nil
        }
        if defaults.object(forKey: DefaultsKeys.bonusSpins) == nil {
            // First install: seed 1 bonus spin
            bonusSpins = 1
            defaults.set(1, forKey: DefaultsKeys.bonusSpins)
        } else {
            bonusSpins = defaults.integer(forKey: DefaultsKeys.bonusSpins)
        }
        if let data = defaults.data(forKey: DefaultsKeys.inventory),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            var temp: [MultiplierTier: Int] = [:]
            for tier in MultiplierTier.allCases {
                if let count = decoded[tier.rawValue], count > 0 {
                    temp[tier] = count
                }
            }
            inventory = temp
        } else {
            inventory = [:]
        }
        if let data = defaults.data(forKey: DefaultsKeys.activeMultiplier),
           let decoded = try? JSONDecoder().decode(ActiveMultiplier.self, from: data) {
            activeMultiplier = decoded
        } else {
            activeMultiplier = nil
        }
        purgeExpiredMultiplier(now: Date())
    }
    
    // MARK: - Slots
    
    public func slotStart(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let seconds = date.timeIntervalSince(startOfDay)
        let slotIndex = Int(seconds / Self.slotInterval)
        return startOfDay.addingTimeInterval(TimeInterval(slotIndex) * Self.slotInterval)
    }
    
    public func nextSlotStart(after date: Date = Date()) -> Date {
        let currentStart = slotStart(for: date)
        let candidate = currentStart.addingTimeInterval(Self.slotInterval)
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = startOfDay.addingTimeInterval(TimeInterval(Self.slotsPerDay) * Self.slotInterval)
        if candidate < endOfDay {
            return candidate
        }
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(24 * 60 * 60)
        return nextDay
    }
    
    public func slotAvailable(on date: Date = Date()) -> Bool {
        guard let last = lastConsumedSlot else { return true }
        let current = slotStart(for: date)
        return current > last
    }
    
    public func beginSpin(now date: Date = Date()) -> SpinSource? {
        purgeExpiredMultiplier(now: date)
        // Use bonus spins first
        if bonusSpins > 0 {
            bonusSpins -= 1
            saveBonusSpins()
            // Always stamp the current slot as consumed so the player
            // doesn't get a free slot spin after exhausting bonus spins
            let current = slotStart(for: date)
            if lastConsumedSlot == nil || current > lastConsumedSlot! {
                lastConsumedSlot = current
                saveLastSlot()
            }
            return .bonus
        } else if slotAvailable(on: date) {
            // Only use the 4-hour slot when no bonus spins remain
            let current = slotStart(for: date)
            lastConsumedSlot = current
            saveLastSlot()
            return .scheduledSlot(current)
        }
        return nil
    }
    
    public func addBonusSpins(_ amount: Int) {
        guard amount > 0 else { return }
        bonusSpins += amount
        saveBonusSpins()
    }

    /// Remove bonus spins (used to defer spins won during multi-spin).
    public func removeBonusSpins(_ amount: Int) {
        guard amount > 0 else { return }
        bonusSpins = max(0, bonusSpins - amount)
        saveBonusSpins()
    }
    
    // MARK: - Multipliers
    
    public func count(for tier: MultiplierTier) -> Int {
        inventory[tier, default: 0]
    }
    
    public func addMultiplier(_ tier: MultiplierTier, count: Int = 1) {
        guard count > 0 else { return }
        inventory[tier, default: 0] += count
        saveInventory()
    }
    
    @discardableResult
    public func activateMultiplier(_ tier: MultiplierTier, now date: Date = Date()) -> Bool {
        purgeExpiredMultiplier(now: date)
        if let current = activeMultiplier, current.expiresAt > date {
            return false
        }
        guard count(for: tier) > 0 else { return false }
        inventory[tier, default: 0] -= 1
        if inventory[tier, default: 0] <= 0 {
            inventory[tier] = nil
        }
        let expires = date.addingTimeInterval(tier.duration)
        activeMultiplier = ActiveMultiplier(tier: tier, expiresAt: expires)
        saveInventory()
        saveActiveMultiplier()
        return true
    }
    
    public func purgeExpiredMultiplier(now date: Date = Date()) {
        if let active = activeMultiplier, active.expiresAt <= date {
            activeMultiplier = nil
            defaults.removeObject(forKey: DefaultsKeys.activeMultiplier)
        }
    }
    
    public func formattedActiveMultiplierCountdown(now date: Date = Date()) -> String {
        guard let active = activeMultiplier else { return "" }
        let remaining = max(0, active.expiresAt.timeIntervalSince(date))
        return Self.formattedBoostDuration(remaining)
    }

    private static func formattedBoostDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    public func refresh(now date: Date = Date()) {
        purgeExpiredMultiplier(now: date)
    }
    
    // MARK: - Countdown
    
    public func formattedCountdown(now date: Date = Date()) -> String {
        if bonusSpins > 0 || slotAvailable(on: date) {
            if bonusSpins == 0 && lastConsumedSlot != nil {
                return "Ready now"
            }
            return "Available"
        }
        let next = nextSlotStart(after: date)
        let remaining = max(0, next.timeIntervalSince(date))
        return Self.formattedDuration(remaining)
    }
    
    private static func formattedDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval.rounded(.towardZero) / 60)
        let hours = totalMinutes / 60
        let minutes = max(0, totalMinutes % 60)
        if hours > 0 && minutes > 0 {
            return "\(hours) hr\(hours == 1 ? "" : "s") \(minutes) min\(minutes == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hr\(hours == 1 ? "" : "s")"
        } else if minutes > 0 {
            return "\(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            return "Less than a minute"
        }
    }
    
    // MARK: - Persistence
    
    private func saveLastSlot() {
        if let date = lastConsumedSlot {
            defaults.set(date.timeIntervalSince1970, forKey: DefaultsKeys.lastSlot)
        } else {
            defaults.removeObject(forKey: DefaultsKeys.lastSlot)
        }
    }
    
    private func saveBonusSpins() {
        defaults.set(bonusSpins, forKey: DefaultsKeys.bonusSpins)
    }
    
    private func saveInventory() {
        var payload: [String: Int] = [:]
        for (tier, count) in inventory where count > 0 {
            payload[tier.rawValue] = count
        }
        if payload.isEmpty {
            defaults.removeObject(forKey: DefaultsKeys.inventory)
        } else if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: DefaultsKeys.inventory)
        }
    }
    
    private func saveActiveMultiplier() {
        if let active = activeMultiplier, let data = try? JSONEncoder().encode(active) {
            defaults.set(data, forKey: DefaultsKeys.activeMultiplier)
        } else {
            defaults.removeObject(forKey: DefaultsKeys.activeMultiplier)
        }
    }
}
