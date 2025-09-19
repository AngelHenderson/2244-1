# Research: Create 2244 - Initial Playable Shell

**Date**: 2025-01-16  
**Feature**: 003-create-2244-initial

## Audio Architecture for Multi-Theme System

### Decision: AVAudioEngine with Node-Based Mixing
**Rationale**: 
- Provides low-latency audio processing (<50ms requirement)
- Supports real-time crossfading between multiple audio sources
- Allows precise control over audio graph for theme transitions
- Built-in support for audio effects and spatial audio

**Alternatives Considered**:
- AVAudioPlayer: Simpler but lacks real-time mixing capabilities
- Core Audio: More powerful but unnecessarily complex for our needs
- AVQueuePlayer: Good for sequential playback but poor for crossfades

### Implementation Strategy:
```swift
// Audio node structure per theme
- AVAudioPlayerNode (background music)
- AVAudioMixerNode (theme mixer)
- AVAudioUnitReverb (optional ambience)
- Main mixer node (crossfade control)
```

## Theme Switching Performance

### Decision: Dual-Buffer Preloading with Lazy Loading
**Rationale**:
- Keep current and next theme loaded in memory
- Lazy load other themes on first selection
- Achieves <500ms crossfade requirement
- Memory efficient (~20MB per theme max)

**Alternatives Considered**:
- Full preload: Too memory intensive (6 themes × 20MB = 120MB)
- On-demand only: Too slow for smooth transitions
- Streaming: Adds complexity and network dependency

### Crossfade Algorithm:
```
1. Start loading next theme at 80% current volume
2. Ramp down current over 400ms
3. Ramp up next over 400ms (overlapping)
4. Release previous theme after 1s delay
```

## Music Theme Asset Structure

### Decision: Bundle Resources with Fallback Chain
**Rationale**:
- Each theme as separate asset catalog
- Hierarchical fallback: Theme → Classic → Silent
- Supports both included and downloadable themes
- Graceful degradation on missing assets

**Asset Organization**:
```
MusicThemes.xcassets/
├── Classic/
│   ├── background.m4a
│   ├── effects.json
│   └── haptics.json
├── Minimal/
├── Retro/
├── Cyberpunk/ (IAP)
├── Lofi/ (IAP)
└── Orchestral/ (IAP)
```

## Sample Project Tasks System

### Decision: Codable Task Definitions with Progress Tracking
**Rationale**:
- Tasks defined in JSON for easy modification
- Progress stored in UserDefaults per profile
- Supports dynamic task addition without app update
- Clean separation of task definition and state

**Task Structure**:
```swift
struct ProjectTask: Codable {
    let id: String
    let title: String
    let projectID: String
    let requiredScore: Int?
    let requiredAction: String?
}

struct TaskProgress: Codable {
    let taskID: String
    var status: TaskStatus
    var completedAt: Date?
}
```

**Alternatives Considered**:
- Hard-coded tasks: Less flexible, requires recompilation
- Server-driven: Unnecessary complexity for local-only feature
- Core Data: Overkill for simple task tracking

## Power-Up System Architecture

### Decision: Protocol-Based Power-Up Commands
**Rationale**:
- Each power-up as conforming type to PowerUpCommand protocol
- Clean separation between UI trigger and engine execution
- Supports undo through command pattern
- Easy to add new power-ups

**Protocol Design**:
```swift
protocol PowerUpCommand {
    func canExecute(on board: Board) -> Bool
    func execute(on board: inout Board) -> PowerUpResult
    func undo(on board: inout Board)
}
```

## Initial Power-Up Distribution

### Decision: Fixed Starting Inventory with Earned Progression
**Rationale**:
- Gives players immediate access to understand mechanics
- Creates desire for more through gameplay
- Based on industry best practices research

**Starting Inventory**:
- Hammer: 3 (basic removal tool)
- Swap: 2 (strategic repositioning)  
- Undo: 5 (forgiving for new players)
- Shuffle: 1 (emergency reset)
- Magnet: 0 (advanced, must earn)
- Double: 0 (premium, must earn)

## Haptic Patterns by Theme

### Decision: Theme-Specific Haptic Dictionaries
**Rationale**:
- Each theme defines its own haptic personality
- Falls back to default if custom not defined
- Respects system haptics toggle
- Uses Core Haptics for precise control

**Pattern Examples**:
- Classic: Subtle impacts and selection taps
- Retro: Sharp, digital-feeling clicks
- Cyberpunk: Glitchy, irregular pulses
- Orchestral: Smooth, musical crescendos

## Performance Optimizations

### Decision: Frame-Rate Aware Animations
**Rationale**:
- Monitor frame rate and adjust quality dynamically
- Reduce particle effects under 50 FPS
- Disable non-essential animations under 30 FPS
- Ensures 60 FPS target on older devices

**Monitoring Strategy**:
```swift
- CADisplayLink for frame timing
- Exponential moving average over 1s
- Three quality tiers: Full, Reduced, Minimal
```

## StoreKit 2 Product Structure

### Decision: Consumable + Non-Consumable Mix
**Rationale**:
- Music themes as non-consumable (permanent unlock)
- Power-up packs as consumables
- Ad removal as non-consumable
- Supports family sharing for non-consumables

**Product IDs**:
```
com.game2244.theme.cyberpunk (non-consumable)
com.game2244.theme.lofi (non-consumable)
com.game2244.theme.orchestral (non-consumable)
com.game2244.adfree (non-consumable)
com.game2244.coins.small (consumable)
com.game2244.coins.medium (consumable)
com.game2244.coins.large (consumable)
```

## Board Configuration

### Decision: 5×8 Fixed Layout
**Rationale**:
- Portrait orientation optimized
- More vertical space for chain building
- Fits well on all iPhone screens
- Allows for longer chains than square boards

**Layout Metrics**:
- Cell size: Dynamic based on screen width
- Spacing: 2-4 points adaptive
- Safe area aware
- Maintains aspect ratio

---

## Summary of Research Outcomes

All technical decisions have been made with no remaining NEEDS CLARIFICATION items:

1. **Audio**: AVAudioEngine with dual-buffer preloading
2. **Themes**: Asset catalogs with hierarchical fallback
3. **Tasks**: JSON-defined with UserDefaults progress tracking
4. **Power-ups**: Protocol-based command pattern
5. **Haptics**: Theme-specific Core Haptics patterns
6. **Performance**: Frame-rate aware quality adjustment
7. **IAP**: StoreKit 2 with mixed product types
8. **Board**: 5×8 fixed layout with adaptive sizing

All decisions align with the constitution requirements for Swift 6, SwiftUI Observation, and 60 FPS performance targets.