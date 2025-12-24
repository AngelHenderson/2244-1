# Achievements View Refactor Strategy

## Overview

This strategy transforms `AchievementsView` from an Apple-style modal/sheet presentation to a Game UI/Immersive full-screen design with a dark purple/navy theme.

---

## Current State Analysis

### Existing Architecture (AchievementsView.swift)
- **Presentation**: `.sheet` from `HomeView.swift:245`
- **Layout**: `NavigationStack` → `ScrollView` → `LazyVStack` (already custom, not List)
- **Components**: `AchievementRow`, `LockupIcon`, `StatusBadge`, `ClaimButton`, `RewardSummary`
- **Theme**: Light mode (systemGroupedBackground, systemGray6)
- **Data Flow**: Uses `@Environment(AchievementStore.self)` for achievements data

### Available Asset Names (Verified in Assets.xcassets)
| Asset Name       | Purpose               | Size Recommendation |
|------------------|-----------------------|---------------------|
| `gem`            | Gems reward           | 55x55pt             |
| `hammer`         | Hammers reward        | 55x55pt             |
| `magnet`         | MegaMerge reward      | 55x55pt             |
| `swap`           | Swaps reward          | 55x55pt             |
| `spinthewheel`   | Spins reward          | 55x55pt             |
| `gift`           | Multiple rewards      | 55x55pt             |
| `achievement`    | Achievement header    | varies              |
| `lockpic`        | Locked state          | 28x28pt (icon)      |

### Assets Using SF Symbols (No image assets)
| Reward Type | SF Symbol             | Color    |
|-------------|-----------------------|----------|
| `boost2x`   | `bolt.circle.fill`    | `.yellow`|
| `boost3x`   | `bolt.circle.fill`    | `.orange`|
| `boost4x`   | `bolt.circle.fill`    | `.pink`  |

---

## Implementation Strategy

### Phase 1: Presentation Change

**File**: `Packages/GameUI/Sources/GameUI/Home/HomeView.swift`

**Change**: Line 244-246
```swift
// FROM:
.sheet(isPresented: $isShowingAchievements) {
    AchievementsView()
}

// TO:
.fullScreenCover(isPresented: $isShowingAchievements) {
    AchievementsView()
}
```

---

### Phase 2: Dark Theme Colors

**Add to AchievementsView.swift** (top of file, after imports):

```swift
// MARK: - Theme Colors
private enum AchievementTheme {
    static let background = Color(red: 0.08, green: 0.06, blue: 0.18) // Deep navy/purple
    static let cardBackground = Color(red: 0.12, green: 0.10, blue: 0.22) // Slightly lighter
    static let cardBorder = Color.white.opacity(0.1)
    static let progressTrack = Color.black.opacity(0.5)
    static let progressFill = Color(red: 0.2, green: 0.9, blue: 0.4) // Neon green
    static let titleText = Color.white
    static let subtitleText = Color.white.opacity(0.7)
    static let accentGreen = Color.green
}
```

---

### Phase 3: Custom Back Button & Header

**Replace NavigationStack with custom header**:

```swift
public var body: some View {
    ZStack {
        // Background
        AchievementTheme.background
            .ignoresSafeArea()

        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                        Text("Back")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                }

                Spacer()

                Text("Achievements")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Spacer()

                // Invisible spacer for balance
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Scrollable Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sortedAchievements) { def in
                        AchievementRow(/* existing params */)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }
    .preferredColorScheme(.dark)
}
```

---

### Phase 4: Redesigned AchievementRow

**New Row Structure** (replaces existing `AchievementRow`):

```swift
private struct AchievementRow: View {
    // ... existing properties ...

    var body: some View {
        HStack(spacing: 16) {
            // LEFT: Status Icon
            StatusIcon(isUnlocked: isUnlocked, isClaimed: isClaimed)
                .frame(width: 50, height: 50)

            // CENTER: Title + Progress
            VStack(alignment: .leading, spacing: 8) {
                Text(displayTitle)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                if let progress = progress {
                    CustomProgressBar(
                        current: progress.current,
                        target: progress.target
                    )
                }
            }

            Spacer()

            // RIGHT: Reward Display (Image above Text)
            RewardDisplay(rewards: rewardsForDisplay, isClaimable: isClaimable)
                .frame(width: 80)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AchievementTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isClaimable ? AchievementTheme.accentGreen : AchievementTheme.cardBorder,
                    lineWidth: isClaimable ? 2 : 1
                )
        )
    }
}
```

---

### Phase 5: Custom Progress Bar Component

```swift
private struct CustomProgressBar: View {
    let current: Double
    let target: Double

    private var percentage: Int {
        guard target > 0 else { return 0 }
        return Int((current / target) * 100)
    }

    private var fillWidth: CGFloat {
        guard target > 0 else { return 0 }
        return CGFloat(current / target)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(AchievementTheme.progressTrack)

                // Fill track
                Capsule()
                    .fill(AchievementTheme.progressFill)
                    .frame(width: geo.size.width * fillWidth)

                // Percentage text overlay
                Text("\(percentage)%")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.leading, 8)
            }
        }
        .frame(height: 16)
    }
}
```

---

### Phase 6: Reward Display Component (Image Above Text)

**This is the key visual change - reward icon prominently displayed above text**:

```swift
private struct RewardDisplay: View {
    let rewards: AchievementDef.Rewards?
    let isClaimable: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Large Reward Icon
            rewardIcon
                .frame(width: 55, height: 55)

            // Reward Text
            Text(rewardText)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Claim indicator (optional)
            if isClaimable {
                Text("CLAIM")
                    .font(.caption2.weight(.black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AchievementTheme.progressFill, in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var rewardIcon: some View {
        if let rewards, let primary = primaryReward(from: rewards) {
            switch primary.type {
            case .gem:
                Image("gem")
                    .resizable()
                    .scaledToFit()
            case .hammer:
                Image("hammer")
                    .resizable()
                    .scaledToFit()
            case .magnet:
                Image("magnet")
                    .resizable()
                    .scaledToFit()
            case .swap:
                Image("swap")
                    .resizable()
                    .scaledToFit()
            case .spin:
                Image("spinthewheel")
                    .resizable()
                    .scaledToFit()
            case .boost2x:
                Image(systemName: "bolt.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.yellow)
            case .boost3x:
                Image(systemName: "bolt.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.orange)
            case .boost4x:
                Image(systemName: "bolt.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.pink)
            case .multiple:
                Image("gift")
                    .resizable()
                    .scaledToFit()
            }
        } else {
            // No rewards - star icon
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(.yellow)
        }
    }

    private var rewardText: String {
        guard let rewards else { return "Glory" }

        var parts: [String] = []
        if let gems = rewards.gems, gems > 0 { parts.append("\(gems) Gems") }
        if let hammers = rewards.hammers, hammers > 0 { parts.append("\(hammers) Hammer\(hammers > 1 ? "s" : "")") }
        if let magnets = rewards.magnets, magnets > 0 { parts.append("\(magnets) Magnet\(magnets > 1 ? "s" : "")") }
        if let swaps = rewards.swaps, swaps > 0 { parts.append("\(swaps) Swap\(swaps > 1 ? "s" : "")") }
        if let spins = rewards.spins, spins > 0 { parts.append("\(spins) Spin\(spins > 1 ? "s" : "")") }
        if let b2 = rewards.boost2x, b2 > 0 { parts.append("\(b2)× 2X") }
        if let b3 = rewards.boost3x, b3 > 0 { parts.append("\(b3)× 3X") }
        if let b4 = rewards.boost4x, b4 > 0 { parts.append("\(b4)× 4X") }

        return parts.isEmpty ? "Glory" : parts.joined(separator: "\n")
    }

    private enum RewardType {
        case gem, hammer, magnet, swap, spin, boost2x, boost3x, boost4x, multiple
    }

    private struct PrimaryReward {
        let type: RewardType
        let amount: Int
    }

    private func primaryReward(from rewards: AchievementDef.Rewards) -> PrimaryReward? {
        var count = 0
        var lastType: RewardType?
        var lastAmount: Int = 0

        if let v = rewards.gems, v > 0 { count += 1; lastType = .gem; lastAmount = v }
        if let v = rewards.hammers, v > 0 { count += 1; lastType = .hammer; lastAmount = v }
        if let v = rewards.magnets, v > 0 { count += 1; lastType = .magnet; lastAmount = v }
        if let v = rewards.swaps, v > 0 { count += 1; lastType = .swap; lastAmount = v }
        if let v = rewards.spins, v > 0 { count += 1; lastType = .spin; lastAmount = v }
        if let v = rewards.boost2x, v > 0 { count += 1; lastType = .boost2x; lastAmount = v }
        if let v = rewards.boost3x, v > 0 { count += 1; lastType = .boost3x; lastAmount = v }
        if let v = rewards.boost4x, v > 0 { count += 1; lastType = .boost4x; lastAmount = v }

        if count == 0 { return nil }
        if count > 1 { return PrimaryReward(type: .multiple, amount: count) }
        return PrimaryReward(type: lastType!, amount: lastAmount)
    }
}
```

---

### Phase 7: Status Icon Component

```swift
private struct StatusIcon: View {
    let isUnlocked: Bool
    let isClaimed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            if isClaimed {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            } else if isUnlocked {
                Image(systemName: "gift.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            } else {
                Image("lockpic")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
    }

    private var backgroundColor: Color {
        if isClaimed {
            return AchievementTheme.accentGreen
        } else if isUnlocked {
            return .orange
        } else {
            return Color.gray.opacity(0.4)
        }
    }
}
```

---

## Asset Mapping Summary

| Recommended Plan Reference | Your Actual Asset      | Notes                          |
|----------------------------|------------------------|--------------------------------|
| "gem_chest"                | `gem` or `gift`        | Use `gem` for gems, `gift` for multiple |
| Lock icon                  | `lockpic` or SF Symbol | Have both available            |
| Checkmark                  | SF Symbol              | `checkmark` or `checkmark.circle.fill` |
| "spin"                     | `spinthewheel`         | **Important**: Asset name differs |
| boost icons                | SF Symbols             | `bolt.circle.fill` with colors |

---

## Files to Modify

1. **`Packages/GameUI/Sources/GameUI/Achievements/AchievementsView.swift`**
   - Complete redesign of all components
   - Add theme colors
   - Replace all subviews

2. **`Packages/GameUI/Sources/GameUI/Home/HomeView.swift`**
   - Line 244: Change `.sheet` to `.fullScreenCover`

---

## Testing Checklist

- [ ] Full screen presentation on iPad
- [ ] Back button dismisses correctly
- [ ] Dark theme renders properly
- [ ] Progress bars show correct percentages
- [ ] Reward icons display at 55x55pt
- [ ] Multiple rewards show gift icon
- [ ] Claimable achievements have green border
- [ ] Claimed achievements show checkmark
- [ ] Locked achievements show lock icon
- [ ] Landscape orientation works correctly

---

## Optional Enhancements

1. **Animation on claim**: Scale/bounce animation when claiming
2. **Haptic feedback**: Light impact on claim button press
3. **Sound effect**: Coin/reward sound on successful claim
4. **Confetti**: Particle effect for milestone achievements
