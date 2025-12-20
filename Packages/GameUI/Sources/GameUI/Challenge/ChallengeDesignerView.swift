import SwiftUI
import GameCore
import GameApp

public struct ChallengeDesignerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.challengeDesignerStore) private var store
    
    public var onPlay: ((CustomChallengeConfig) -> Void)?
    
    public init(onPlay: ((CustomChallengeConfig) -> Void)? = nil) {
        self.onPlay = onPlay
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    targetSection
                    steppersSection
                    bucketsSection
                }
                .padding()
            }
            .navigationTitle("DESIGN YOUR OWN CHALLENGE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
    }
    
    private var targetSection: some View {
        VStack(spacing: 12) {
            Text("TARGET")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                Button {
                    store.prevTarget()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.secondary.opacity(0.2)))
                }
                .buttonStyle(.plain)
                
                Text(store.targetLabel)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .frame(minWidth: 120)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.purple.opacity(0.18)))
                
                Button {
                    store.nextTarget()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.secondary.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var steppersSection: some View {
        HStack(spacing: 12) {
            StepperBox(
                title: "Time",
                value: "\(store.timeLimitSeconds)s",
                onDecrease: { store.decTime() },
                onIncrease: { store.incTime() }
            )
            
            StepperBox(
                title: "Min Tile",
                value: "\(1 << store.minTileLevel)",
                onDecrease: { store.decMinTile() },
                onIncrease: { store.incMinTile() }
            )
            
            StepperBox(
                title: "Levels",
                value: "\(store.levels)",
                onDecrease: { store.decLevels() },
                onIncrease: { store.incLevels() }
            )
        }
    }
    
    private var bucketsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ForEach(TileBucket.allCases, id: \.self) { bucket in
                    Text(bucketTitle(for: bucket))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            HStack(alignment: .top, spacing: 12) {
                ForEach(TileBucket.allCases, id: \.self) { bucket in
                    BucketColumn(bucket: bucket, store: store)
                }
            }
        }
    }
    
    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "diamond.fill")
                Text("+\(store.predictedReward)")
            }
            .font(.system(.headline, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.15)))
            
            Spacer(minLength: 0)
            
            Button {
                onPlay?(store.config)
                dismiss()
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.green.opacity(0.9)))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .disabled(!store.isPlayable)
            .opacity(store.isPlayable ? 1 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private func bucketTitle(for bucket: TileBucket) -> String {
        switch bucket {
        case .low: return "Low Tiles"
        case .mid: return "Mid Tiles"
        case .high: return "High Tiles"
        }
    }
}

private struct BucketColumn: View {
    let bucket: TileBucket
    let store: ChallengeDesignerStore
    
    var body: some View {
        VStack(spacing: 8) {
            let tiles = store.tileAssignments
                .filter { $0.value == bucket }
                .map(\.key)
                .sorted()
            
            ScrollView {
                if tiles.isEmpty {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 96)
                        .overlay(
                            Text("Tap + to add")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        )
                } else {
                    VStack(spacing: 8) {
                        ForEach(tiles, id: \.self) { tile in
                            TileChip(value: tile) {
                                store.cycleBucket(for: tile)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            
            Menu {
                ForEach(availableTiles, id: \.self) { value in
                    Button("\(value)") {
                        store.addTile(value, to: bucket)
                    }
                }
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .disabled(availableTiles.isEmpty)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
    }
    
    private var availableTiles: [Int] {
        store.candidateTiles.filter { store.tileAssignments[$0] == nil }
    }
}

private struct StepperBox: View {
    let title: String
    let value: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                Button(action: onDecrease) {
                    Image(systemName: "minus")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.secondary.opacity(0.2)))
                }
                .buttonStyle(.plain)
                
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .frame(minWidth: 56)
                
                Button(action: onIncrease) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.secondary.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.12)))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TileChip: View {
    let value: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text("\(value)")
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}

extension Int {
    var abbreviated: String {
        if self >= 1_000_000_000 { return "\(self / 1_000_000_000)B" }
        if self >= 1_000_000 { return "\(self / 1_000_000)M" }
        if self >= 1_000 { return "\(self / 1_000)K" }
        return "\(self)"
    }
}

#Preview("Challenge Designer") {
    ChallengeDesignerView { config in
        print("Starting custom challenge: \(config)")
    }
    .environment(\.challengeDesignerStore, ChallengeDesignerStore())
}