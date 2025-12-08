import SwiftUI
import GameApp
import GameCore

struct UnlockedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    @Environment(\.gameStore) private var gameStore
    @State private var showClaimOption = false
    @State private var selectedMultiplier = 1

    private var journeyReward: (previous: String?, current: String, next: String?) {
        // Get journey tier labels for the progression
        if let tile = Tile.makeFromValue(value) {
            if let currentTier = JourneyAbbreviationTiers.tier(for: tile) {
                let prevTier = currentTier.order > 0 ?
                    JourneyAbbreviationTiers.tiers[safe: currentTier.order - 1] : nil
                let nextTier = JourneyAbbreviationTiers.tiers[safe: currentTier.order + 1]

                return (prevTier?.label, currentTier.label, nextTier?.label)
            }
        }
        // Default progression
        return (nil, CompactNumberFormatter.format(value), nil)
    }

    private var coinReward: Int {
        // Calculate base coin reward based on tile value
        let baseReward = min(value / 100, 999)
        return baseReward * selectedMultiplier
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("EXCELLENT")
                .font(.title2.weight(.bold))
                .padding(.bottom, 8)

            // Journey progression - Simple text display
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Previous tier (if exists)
                    if let prev = journeyReward.previous {
                        Text(prev)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: 80, height: 80)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Current unlocked tier (highlighted)
                    Text(journeyReward.current)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 100)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .orange.opacity(0.5), radius: 8)
                        .overlay(alignment: .top) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                                .offset(y: -15)
                        }

                    // Next tier (locked)
                    if let next = journeyReward.next {
                        Text(next)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.gray)
                            .frame(width: 80, height: 80)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.gray)
                                    .font(.caption)
                                    .offset(x: 5, y: -5)
                            }
                    }
                }
                Text("New Milestone Unlocked!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            // Reward section
            VStack(spacing: 12) {
                Text("Your Reward")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "bitcoinsign.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    Text("+\(coinReward)")
                        .font(.title2.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.15))
                .cornerRadius(12)
            }

            // Multiplier options
            if showClaimOption {
                // TODO: Add MultiplierSelectorView
                // MultiplierSelectorView(selectedMultiplier: $selectedMultiplier)
                //     .padding(.vertical, 8)

                Button(action: {
                    // Claim with multiplier (watch ad if > 1)
                    if selectedMultiplier > 1 {
                        // Show ad then grant reward
                    }
                    gameStore.claimJourneyReward(coins: coinReward)
                    onClose()
                }) {
                    HStack {
                        Image(systemName: selectedMultiplier > 1 ? "play.rectangle.fill" : "checkmark")
                        Text(selectedMultiplier > 1 ? "Claim ×\(selectedMultiplier)" : "Claim")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedMultiplier > 1 ? Color.green : Color.blue)
                    .cornerRadius(12)
                }
            } else {
                Button("Continue") {
                    showClaimOption = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
    }
}

struct AddedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Tile Added")
                .font(.title2.weight(.bold))
            
            Text("Added")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            TileView(tile: Tile(value: value), isSelected: false, isValid: true, size: 120)
                .accessibilityLabel("Added tile \(value)")
            
            Text(CompactNumberFormatter.format(value))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Button("Continue") { onClose() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}

struct ExcludedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Tile Excluded")
                .font(.title2.weight(.bold))
            
            Text("Eliminated")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            TileView(tile: Tile(value: value), isSelected: false, isValid: true, size: 120)
                .accessibilityLabel("Excluded tile \(value)")
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                        .offset(x: 8, y: -8)
                }
            
            Text(CompactNumberFormatter.format(value))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Button("Continue") { onClose() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}

