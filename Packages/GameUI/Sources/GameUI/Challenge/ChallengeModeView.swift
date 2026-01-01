import SwiftUI
import GameCore
import GameApp

public struct ChallengeModeView: View {
    @Environment(\.challengeStore) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var scrollViewProxy: ScrollViewProxy? = nil
    
    public var onPlay: ((Challenge) -> Void)?
    
    public init(onPlay: ((Challenge) -> Void)? = nil) {
        self.onPlay = onPlay
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        ZStack(alignment: .leading) {
                            timelineSpine
                            
                            VStack(spacing: 24) {
                                ForEach(Array(store.challenges.enumerated()), id: \.element.id) { index, challenge in
                                    ChallengeCard(
                                        challenge: challenge,
                                        challengeNumber: index + 1,
                                        status: store.status(for: challenge)
                                    )
                                    .id(challenge.id)
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 32)
                        }
                        .padding(.horizontal, 16)
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                        if let active = store.activeChallenge {
                            proxy.scrollTo(active.id, anchor: .center)
                        }
                    }
                }
                
                playButton
            }
            .navigationTitle("CHALLENGE MODE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var timelineSpine: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 4)
                .frame(height: geo.size.height)
                .padding(.leading, 36)
        }
    }
    
    private var playButton: some View {
        Button {
            if let active = store.activeChallenge {
                onPlay?(active)
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Play Challenge \(store.currentChallengeNumber)")
            }
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .disabled(store.activeChallenge == nil)
    }
}

private struct ChallengeCard: View {
    let challenge: Challenge
    let challengeNumber: Int
    let status: ChallengeStatus

    // Format tile target for display using TileStepLabelFormatter
    private var targetTileLabel: String {
        guard let targetTile = challenge.targetTile else { return "??" }

        // Special case for Infinity
        if targetTile == Int.max {
            return "∞"
        }

        // Use TileStepLabelFormatter for proper step-to-label conversion
        return TileStepLabelFormatter.labelForStep(targetTile, start: 2)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Challenge \(challengeNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if status == .locked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(targetTileLabel)
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(status == .locked ? .secondary : .primary)
            
            VStack(spacing: 6) {
                if status == .active {
                    Text(challenge.name)
                        .font(.headline)
                    Text(challenge.description)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if status == .completed {
                    Text("Completed")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.green)
                } else {
                    Text("Locked")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                if status != .completed {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.caption)
                        Text("\(challenge.reward.coins)")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(status == .active ? .orange : .secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(status == .active ? Color.green : Color.clear, lineWidth: 3)
        )
        .overlay(alignment: .leading) {
            Circle()
                .fill(nodeFill)
                .frame(width: 12, height: 12)
                .offset(x: -44)
        }
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        switch status {
        case .completed:
            Color(UIColor.systemGray6)
        case .active:
            LinearGradient(
                colors: [
                    Color(UIColor.systemGray6),
                    Color(UIColor.systemGray5).opacity(0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .locked:
            Color(UIColor.systemGray5).opacity(0.6)
        }
    }
    
    private var nodeFill: Color {
        switch status {
        case .active:
            return .green
        case .completed:
            return .secondary.opacity(0.6)
        case .locked:
            return .secondary.opacity(0.3)
        }
    }
}

#Preview("Challenge Mode") {
    let store = ChallengeStore()
    // Mark first two challenges as completed
    if store.challenges.count >= 2 {
        store.markCompleted(store.challenges[0].id)
        store.markCompleted(store.challenges[1].id)
    }

    return ChallengeModeView()
        .environment(\.challengeStore, store)
}