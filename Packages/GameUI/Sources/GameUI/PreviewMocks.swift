import SwiftUI
import GameCore
import GameApp

// MARK: - Preview-Safe GameStore Mock
// Avoids Firebase JIT linking failures by providing a stub that doesn't import GameServices

/// A preview-safe GameStore that mirrors the real API but has no Firebase dependencies.
/// Used ONLY in #Preview blocks to avoid JIT runtime linking errors.
@MainActor
@Observable
public final class PreviewGameStore {
    public var achievementEvaluator: PreviewAchievementEvaluator? = PreviewAchievementEvaluator()
    
    public init() {}
    
    public func registerSpinUse() {}
    public func addPowerUp(_ type: String, count: Int) {}
    public func addCoins(_ amount: Int) {}
    public func saveProgressToStore() {}
}

/// Preview-safe achievement evaluator stub
@MainActor
public final class PreviewAchievementEvaluator {
    public init() {}
    public func onSpinPurchased(count: Int) {}
    public func onWheelCollected(count: Int) {}
    public func onBoost2xUsed() {}
    public func onBoost3xUsed() {}
    public func onBoost4xUsed() {}
}

/// Preview-safe haptics stub (avoids importing GameServices)
@MainActor
public final class PreviewHapticsService {
    public init() {}
    public func lightImpact() {}
    public func mediumImpact() {}
    public func heavyImpact() {}
    public func success() {}
    public func warning() {}
    public func error() {}
}

// MARK: - Preview Environment Keys

private struct PreviewGameStoreKey: EnvironmentKey {
    nonisolated static var defaultValue: PreviewGameStore {
        MainActor.assumeIsolated { PreviewGameStore() }
    }
}

private struct PreviewHapticsKey: EnvironmentKey {
    nonisolated static var defaultValue: PreviewHapticsService {
        MainActor.assumeIsolated { PreviewHapticsService() }
    }
}

extension EnvironmentValues {
    var previewGameStore: PreviewGameStore {
        get { self[PreviewGameStoreKey.self] }
        set { self[PreviewGameStoreKey.self] = newValue }
    }
    
    var previewHaptics: PreviewHapticsService {
        get { self[PreviewHapticsKey.self] }
        set { self[PreviewHapticsKey.self] = newValue }
    }
}

// MARK: - Preview Wrapper View

/// A wrapper that provides all required environment objects for previews.
/// This avoids triggering the real GameStore initialization which would pull in Firebase.
public struct SpinWheelPreviewWrapper: View {
    @State private var homeState = HomeState()
    @State private var previewStore = PreviewGameStore()
    @State private var previewHaptics = PreviewHapticsService()
    
    public init() {
        // Set up preview-friendly defaults
        _homeState = State(initialValue: {
            let state = HomeState()
            state.gems = 10000
            return state
        }())
    }
    
    public var body: some View {
        SpinWheelPreviewContent()
            .environment(homeState)
            .environment(\.wheelEngine, WheelEngine())
            .environment(\.spinWheelState, SpinWheelState())
            .environment(\.previewGameStore, previewStore)
            .environment(\.previewHaptics, previewHaptics)
    }
}

/// The actual preview content - uses previewGameStore instead of gameStore
struct SpinWheelPreviewContent: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wheelEngine) private var engine
    @Environment(\.previewGameStore) private var gameStore
    @Environment(\.previewHaptics) private var haptics
    @Environment(HomeState.self) private var homeState
    @Environment(\.spinWheelState) private var spinState
    @State private var showReward = false
    @State private var rewardMessage = ""
    @State private var purchaseFeedback: String?
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var slotReady: Bool { spinState.slotAvailable(on: now) }
    private var bonusReady: Bool { spinState.bonusSpins > 0 }
    private var canSpin: Bool { (slotReady || bonusReady) && !engine.isSpinning }
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    // Simplified background for preview
                    Color(red: 0.05, green: 0.03, blue: 0.11)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        // Simplified header
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text("SPIN")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(homeState.gems) 💎")
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        // Wheel placeholder
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.10, green: 0.10, blue: 0.24))
                            
                            WheelFace(segments: engine.segments)
                                .rotationEffect(.radians(Double(engine.angle)))
                            
                            Circle()
                                .fill(.ultraThickMaterial)
                                .frame(width: 70, height: 70)
                        }
                        .frame(width: 350, height: 350)
                        
                        Spacer()
                        
                        // Spin button
                        Button("SPIN") {
                            haptics.mediumImpact()
                            engine.spin { _ in }
                        }
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .foregroundStyle(.white)
                        .background(.green.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Preview

#Preview("SpinWheel (Mock)") {
    SpinWheelPreviewWrapper()
}
