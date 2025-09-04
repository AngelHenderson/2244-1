import SwiftUI
import Observation
import Foundation

// MARK: - Tile Journey (drop-in)

public enum JourneyKit {
  public typealias TileValue = Int

  // Configure the ladder once for your app.
  // Example: minPower=10 (2^10=1024), maxPower=15 (32768).
  public struct Config: Sendable, Equatable {
    public var minPower: Int
    public var maxPower: Int
    public static let `default` = Self(minPower: 10, maxPower: 17)
    
    public init(minPower: Int, maxPower: Int) {
      self.minPower = minPower
      self.maxPower = maxPower
    }
  }

  public struct Milestone: Identifiable, Codable, Hashable, Sendable {
    public var value: TileValue
    public var claimed: Bool = false
    public var id: TileValue { value }
  }

  public struct State: Codable, Hashable, Sendable {
    public var highestTile: TileValue
    public var claimed: Set<TileValue>     // Set of tile values that have been "claimed" (reward tapped, etc.)
    public var version: Int = 1
  }

  public enum Event: Sendable, Equatable {
    case highestUpdated(TileValue)      // e.g., 2048
    case milestoneUnlocked(TileValue)   // e.g., 4096
    case milestoneClaimed(TileValue)    // e.g., 2048
  }

  // MARK: - Pure Engine (no side effects)
  public struct Engine: Sendable {
    public var config: Config
    
    public init(config: Config) {
      self.config = config
    }

    public func milestones() -> [TileValue] {
      guard config.maxPower >= config.minPower else { return [] }
      return Array(config.minPower...config.maxPower).map { 1 << $0 }  // [2^min ... 2^max]
    }

    /// Index inside the ladder for a power-of-two tile (nil if out of range).
    public func ladderIndex(for tile: TileValue) -> Int? {
      guard tile > 0, tile & (tile - 1) == 0 else { return nil } // must be power of two
      let power = Int(log2(Double(tile)))
      let idx = power - config.minPower
      let ms = milestones()
      return (0..<ms.count).contains(idx) ? idx : nil
    }

    /// Floors an arbitrary tile (e.g., 3072) to the nearest lower milestone (2048).
    public func clampToLadder(_ tile: TileValue) -> TileValue {
      let ms = milestones()
      if ms.contains(tile) { return tile }
      return ms.last(where: { $0 <= tile }) ?? ms.first ?? 2
    }

    public func nextMilestone(after tile: TileValue) -> TileValue? {
      let clamped = clampToLadder(tile)
      let ms = milestones()
      guard let idx = ms.firstIndex(of: clamped) else { return ms.first }
      let nextIdx = idx + 1
      return nextIdx < ms.count ? ms[nextIdx] : nil
    }

    public func previousMilestone(before tile: TileValue) -> TileValue? {
      let clamped = clampToLadder(tile)
      let ms = milestones()
      guard let idx = ms.firstIndex(of: clamped) else { return nil }
      let prevIdx = idx - 1
      return prevIdx >= 0 ? ms[prevIdx] : nil
    }

    /// Returns every milestone newly crossed when going from `old` -> `new`.
    public func unlockedBetween(old: TileValue, new: TileValue) -> [TileValue] {
      guard new > old else { return [] }
      let ms = milestones()
      let lower = clampToLadder(old)
      let upper = clampToLadder(new)
      guard let li = ms.firstIndex(of: lower), let ui = ms.firstIndex(of: upper) else { return [] }
      // If both clamp to the same milestone (or no gap), nothing was unlocked
      guard li + 1 <= ui else { return [] }
      return Array(ms[(li + 1)...ui])
    }

    /// Slice around the current milestone for the UI ribbon (prev/current/next…).
    public func path(around current: TileValue, ahead countAhead: Int = 2) -> [TileValue] {
      let ms = milestones()
      let cur = clampToLadder(current)
      guard let idx = ms.firstIndex(of: cur) else { return Array(ms.prefix(4)) }
      
      // Show more context: up to 2 previous and 2 ahead
      let start = max(0, idx - 2)
      let end = min(idx + countAhead, ms.count - 1)
      
      // Ensure we show at least 3-5 milestones for better context
      let path = Array(ms[start...end])
      if path.count < 3 && ms.count >= 3 {
        return Array(ms.prefix(3))
      }
      return path
    }

    /// Progress toward the next milestone as 0…1 (useful for a progress ring/bar).
    public func progressFraction(currentTile: TileValue) -> Double {
      let ms = milestones()
      let lower = clampToLadder(currentTile)
      guard let li = ms.firstIndex(of: lower) else { return 0 }
      let next = li + 1 < ms.count ? ms[li + 1] : lower
      if next == lower { return 1 }
      let span = Double(next - lower)
      let delta = Double(currentTile - lower)
      return max(0, min(1, delta / span))
    }
  }

  // MARK: - Persistence bridge (no @AppStorage in an @Observable)
  public protocol KeyValueStore: Sendable {
    func data(forKey: String) -> Data?
    func set(_ data: Data?, forKey: String)
  }

  public struct UserDefaultsStore: KeyValueStore {
    public init() {}
    
    public func data(forKey key: String) -> Data? {
      UserDefaults.standard.data(forKey: key)
    }
    
    public func set(_ data: Data?, forKey key: String) {
      UserDefaults.standard.set(data, forKey: key)
    }
  }

  // MARK: - Observable Store
  @MainActor
  @Observable
  public final class Store {
    private let engine: Engine
    private let kv: KeyValueStore
    private let stateKey = "journey.state.v1"

    // Observable state
    public var highestTile: TileValue
    public var claimed: Set<TileValue>

    // Async event stream (yield unlocks, claims, highest changes)
    public nonisolated let events: AsyncStream<Event>
    private nonisolated let continuation: AsyncStream<Event>.Continuation

    public init(store: KeyValueStore = UserDefaultsStore(),
                config: Config = .default) {
      self.kv = store
      self.engine = Engine(config: config)

      // Load or seed - use 2 as the base if no saved state exists
      let defaultHighest: TileValue = 2
      let initial: State = Self.load(from: store, key: stateKey)
      ?? State(highestTile: defaultHighest, claimed: [])
      self.highestTile = initial.highestTile
      self.claimed = initial.claimed

      let pair = AsyncStream<Event>.makeStream()
      self.events = pair.stream
      self.continuation = pair.continuation
    }

    // Read helpers for the UI / game
    public func milestones() -> [TileValue] { engine.milestones() }
    public func path() -> [TileValue] { engine.path(around: highestTile) }
    public func nextMilestone() -> TileValue? { engine.nextMilestone(after: highestTile) }
    /// Current milestone (clamped to the ladder) for UI comparisons
    public func currentMilestone() -> TileValue { engine.clampToLadder(highestTile) }
    public func progress(toNextFrom currentTile: TileValue) -> Double {
      engine.progressFraction(currentTile: currentTile)
    }
    
    /// Get a visual journey path optimized for vertical display (shows 4-5 milestones)
    public func visualJourneyPath() -> [TileValue] {
      let ms = engine.milestones()
      let cur = engine.clampToLadder(highestTile)
      guard let idx = ms.firstIndex(of: cur) else { 
        // Return first few milestones if current not found
        return Array(ms.prefix(4))
      }
      
      // For visual display: always show at least 1 below, current, and 2 above
      var path: [TileValue] = []
      
      // Always add at least 1 previous milestone if it exists
      if idx > 0 {
        path.append(ms[idx - 1])
      }
      
      // Add current
      path.append(ms[idx])
      
      // Add up to 2 next milestones for future goals
      if idx + 1 < ms.count {
        path.append(ms[idx + 1])
      }
      if idx + 2 < ms.count {
        path.append(ms[idx + 2])
      }
      
      // If we only have 3 items and there's a second previous milestone, add it
      if path.count == 3 && idx > 1 {
        path.insert(ms[idx - 2], at: 0)
      }
      
      return path
    }

    /// Call this whenever your merge logic creates a new tile on the board.
    public func didReach(tile newTile: TileValue) {
      guard newTile > 0 else { return }
      let old = highestTile
      let lifted = max(old, newTile)
      if lifted != old {
        highestTile = lifted
        continuation.yield(.highestUpdated(lifted))
        for m in engine.unlockedBetween(old: old, new: lifted) where !claimed.contains(m) {
          continuation.yield(.milestoneUnlocked(m))
        }
        persist()
      }
    }

    /// Call when the user taps "Claim" for a milestone reward.
    public func claim(_ milestone: TileValue) {
      guard engine.milestones().contains(milestone) else { return }
      if !claimed.contains(milestone) {
        claimed.insert(milestone)
        continuation.yield(.milestoneClaimed(milestone))
        persist()
      }
    }

    /// Optional: wipe progress (for QA / debug menus).
    public func hardReset() {
      highestTile = engine.milestones().first ?? 2
      claimed.removeAll()
      persist()
    }

    private func persist() {
      let s = State(highestTile: highestTile, claimed: claimed)
      Self.save(s, to: kv, key: stateKey)
    }

    private static func load(from kv: KeyValueStore, key: String) -> State? {
      guard let d = kv.data(forKey: key) else { return nil }
      return try? JSONDecoder().decode(State.self, from: d)
    }

    private static func save(_ state: State, to kv: KeyValueStore, key: String) {
      let data = try? JSONEncoder().encode(state)
      kv.set(data, forKey: key)
    }
  }
}

// MARK: - Environment hook (inject once at the app root)
private struct TileJourneyStoreKey: EnvironmentKey {
  nonisolated static var defaultValue: JourneyKit.Store {
    MainActor.assumeIsolated {
      JourneyKit.Store()
    }
  }
}

public extension EnvironmentValues {
  var tileJourney: JourneyKit.Store {
    get { self[TileJourneyStoreKey.self] }
    set { self[TileJourneyStoreKey.self] = newValue }
  }
}

// MARK: - Small helper so AsyncStream.makeStream() exists on all supported SDKs
private extension AsyncStream {
  static func makeStream() -> (stream: AsyncStream<Element>, continuation: Continuation) {
    var cont: Continuation!
    let stream = AsyncStream<Element> { cont = $0 }
    return (stream, cont)
  }
}
