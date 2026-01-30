import SwiftUI
import GameCore
import GameApp

public struct ChallengeDesignerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.challengeDesignerStore) private var store
    @Environment(\.currentTheme) private var currentTheme

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
                    tilesSection
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
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(currentTheme?.colorForStep(store.targetStep) ?? Theme.colorForStep(store.targetStep))
                        .frame(width: 80, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                    Text(store.targetLabel)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(currentTheme?.textColorForStep(store.targetStep) ?? Theme.textColorForStep(store.targetStep))
                        .minimumScaleFactor(0.5)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                }
                
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
                value: "\(store.minTileLevel)",
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
    
    private var tilesSection: some View {
        VStack(spacing: 16) {
            // Column headers
            HStack {
                ForEach(0..<3, id: \.self) { _ in
                    Text("Tiles")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            // Tiles distributed across 3 columns
            HStack(alignment: .top, spacing: 12) {
                ForEach(0..<3, id: \.self) { columnIndex in
                    VStack(spacing: 8) {
                        ForEach(stepsForColumn(columnIndex), id: \.self) { step in
                            TileChip(step: step, theme: currentTheme)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            // Reward section
            VStack(spacing: 6) {
                Text("REWARD")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image("gem")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("+\(store.predictedReward)")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.15)))
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.15))
        )
    }

    private func stepsForColumn(_ column: Int) -> [Int] {
        let steps = store.candidateTileSteps
        guard !steps.isEmpty else { return [] }

        // Distribution: 1-4 in column 1, 5-8 in column 2, 9-10 in column 3
        switch column {
        case 0:
            // First column: tiles 1-4 (indices 0-3)
            let end = min(4, steps.count)
            return Array(steps.prefix(end))
        case 1:
            // Second column: tiles 5-8 (indices 4-7)
            guard steps.count > 4 else { return [] }
            let start = 4
            let end = min(8, steps.count)
            return Array(steps[start..<end])
        case 2:
            // Third column: tiles 9-10 (indices 8-9)
            guard steps.count > 8 else { return [] }
            return Array(steps[8...])
        default:
            return []
        }
    }
    
    private var bottomBar: some View {
        HStack {
            Spacer()

            Button {
                onPlay?(store.config)
                dismiss()
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.green.opacity(0.9)))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            .disabled(!store.isPlayable)
            .opacity(store.isPlayable ? 1 : 0.5)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassBackground()
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
    let step: Int
    let theme: ThemeDescriptor?
    private let tileSize: CGFloat = 52

    private var tileColor: Color {
        theme?.colorForStep(step) ?? Theme.colorForStep(step)
    }

    private var textColor: Color {
        theme?.textColorForStep(step) ?? Theme.textColorForStep(step)
    }

    var body: some View {
        ZStack {
            // Tile background
            RoundedRectangle(cornerRadius: 10)
                .fill(tileColor)
                .frame(width: tileSize, height: tileSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)

            // Tile label
            Text(TileStepLabelFormatter.labelForStep(step))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
        }
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