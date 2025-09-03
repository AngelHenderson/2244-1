import SwiftUI
import GameApp
import GameCore

struct JourneyPreview: View {
    @Environment(\.tileJourney) private var journey
    @Environment(\.gameStore) private var gameStore
    
    var body: some View {
        VStack(spacing: 12) {
            // Milestone ribbon with claim states
            HStack(spacing: 8) {
                ForEach(journey.path().prefix(5), id: \.self) { value in
                    MilestonePreviewTile(
                        value: value,
                        unlocked: value <= journey.highestTile,
                        claimed: journey.claimed.contains(value),
                        isCurrent: value == journey.highestTile
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            // Progress indicator to next milestone
            if let next = journey.nextMilestone() {
                VStack(spacing: 4) {
                    HStack {
                        Text("Next: \(formatMilestone(next))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(journey.progress(toNextFrom: journey.highestTile) * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: journey.progress(toNextFrom: journey.highestTile))
                        .progressViewStyle(.linear)
                        .tint(.green)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func formatMilestone(_ value: Int) -> String {
        if value >= 1024 && value % 1024 == 0 {
            return "\(value / 1024)K"
        }
        return "\(value)"
    }
}

private struct MilestonePreviewTile: View {
    let value: Int
    let unlocked: Bool
    let claimed: Bool
    let isCurrent: Bool
    
    @Environment(\.tileJourney) private var journey
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if unlocked {
                    TileView(
                        tile: Tile(value: value),
                        isSelected: false,
                        isValid: true,
                        size: 52
                    )
                } else {
                    // Locked tile
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundStyle(.tertiary)
                        )
                }
                
                // Overlay badges
                if unlocked && claimed {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white))
                        }
                        Spacer()
                    }
                    .padding(2)
                }
                
                // Current indicator
                if isCurrent {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.green, lineWidth: 2)
                }
            }
            .frame(width: 52, height: 52)
            
            // Claimable indicator
            if unlocked && !claimed && value <= journey.highestTile {
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 6, height: 6)
            }
        }
    }
}


