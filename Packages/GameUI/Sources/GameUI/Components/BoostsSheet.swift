import SwiftUI
import GameApp

/// Sheet view displaying all boost and discount purchase options
public struct BoostsSheet: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.toastManager) private var toastManager
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Score Boosts Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(
                            title: "Score Boosts",
                            icon: "bolt.fill",
                            color: .yellow
                        )

                        ForEach(GameStore.ScoreBoostTierID.allCases, id: \.self) { tierID in
                            scoreBoostRow(for: tierID)
                        }
                    }

                    Divider()
                        .background(.white.opacity(0.2))

                    // Power Discounts Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(
                            title: "Power-Up Discounts",
                            icon: "wand.and.stars",
                            color: .purple
                        )

                        ForEach(GameStore.PowerDiscountTierID.allCases, id: \.self) { tierID in
                            powerDiscountRow(for: tierID)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.black.opacity(0.95))
            .navigationTitle("Boosts & Discounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.bottom, 4)
    }

    private func scoreBoostRow(for tierID: GameStore.ScoreBoostTierID) -> some View {
        let label = gameStore.scoreBoostLabel(for: tierID)
        let cost = gameStore.scoreBoostCost(for: tierID)
        let countdown = gameStore.scoreBoostCountdownText(for: tierID)
        let isActive = gameStore.isScoreBoostActive(for: tierID)
        let isQueued = gameStore.isScoreBoostQueued(for: tierID)
        let canPurchase = gameStore.canPurchaseScoreBoost(tierID)

        return boostRow(
            icon: "bolt.fill",
            iconColor: isActive ? .yellow : .white,
            label: label,
            cost: cost,
            statusText: countdown,
            isActive: isActive,
            isQueued: isQueued,
            canPurchase: canPurchase,
            action: {
                let wasActive = isActive
                let wasQueued = isQueued
                if gameStore.purchaseScoreBoost(tierID) {
                    // Track achievement for 5x boost usage
                    if tierID == .fiveX {
                        gameStore.achievementEvaluator?.onBoost5xUsed()
                    }
                    if wasActive || wasQueued {
                        toastManager.show("\(label) Extended!", icon: "clock.arrow.circlepath", iconColor: .green)
                    } else if gameStore.isScoreBoostActive(for: tierID) {
                        toastManager.showBoostActivated(label)
                    } else {
                        toastManager.showBoostQueued(label)
                    }
                    dismiss()
                }
            }
        )
    }

    private func powerDiscountRow(for tierID: GameStore.PowerDiscountTierID) -> some View {
        let label = gameStore.powerDiscountLabel(for: tierID)
        let cost = gameStore.powerDiscountCost(for: tierID)
        let countdown = gameStore.powerDiscountCountdownText(for: tierID)
        let isActive = gameStore.isPowerDiscountActive(for: tierID)
        let isQueued = gameStore.isPowerDiscountQueued(for: tierID)
        let canPurchase = gameStore.canPurchasePowerDiscount(tierID)

        return boostRow(
            icon: "wand.and.stars",
            iconColor: isActive ? .purple : .white,
            label: label,
            cost: cost,
            statusText: countdown,
            isActive: isActive,
            isQueued: isQueued,
            canPurchase: canPurchase,
            action: {
                let wasActive = isActive
                let wasQueued = isQueued
                if gameStore.purchasePowerDiscount(tierID) {
                    if wasActive || wasQueued {
                        toastManager.show("\(label) Extended!", icon: "clock.arrow.circlepath", iconColor: .green)
                    } else if gameStore.isPowerDiscountActive(for: tierID) {
                        toastManager.showDiscountActivated(label)
                    } else {
                        toastManager.showBoostQueued(label)
                    }
                    dismiss()
                }
            }
        )
    }

    private func boostRow(
        icon: String,
        iconColor: Color,
        label: String,
        cost: Int,
        statusText: String,
        isActive: Bool,
        isQueued: Bool,
        canPurchase: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let statusColor: Color = {
            if isActive { return .green }
            if isQueued { return .yellow }
            return .white.opacity(0.6)
        }()

        return Button(action: action) {
            HStack(spacing: 14) {
                // Icon with status ring
                ZStack {
                    Circle()
                        .fill(isActive ? iconColor.opacity(0.2) : .white.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconColor)

                    if isActive {
                        Circle()
                            .strokeBorder(iconColor, lineWidth: 2)
                            .frame(width: 44, height: 44)
                    }
                }

                // Label and status
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(statusText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(statusColor)
                }

                Spacer()

                // Cost badge
                HStack(spacing: 4) {
                    Image("gem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text(cost.formatted(.number.grouping(.automatic)))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(canPurchase ? Color.green.opacity(0.3) : Color.gray.opacity(0.3))
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isActive ? iconColor.opacity(0.5) : .white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(canPurchase ? 1.0 : 0.5)
        .disabled(!canPurchase)
    }
}

// MARK: - Compact Boost Status Button

/// A compact button showing active boost status, opens BoostsSheet on tap
public struct BoostStatusButton: View {
    @Environment(\.gameStore) private var gameStore
    @State private var isShowingSheet = false

    public init() {}

    public var body: some View {
        Button(action: { isShowingSheet = true }) {
            HStack(spacing: 6) {
                // Show active boost icons
                if hasActiveScoreBoost {
                    Image(systemName: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.yellow)
                }

                if hasActivePowerDiscount {
                    Image(systemName: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }

                // If nothing active, show general boost icon
                if !hasActiveScoreBoost && !hasActivePowerDiscount {
                    Image(systemName: "bolt.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Countdown for active boost
                if let countdownText = activeCountdownText {
                    Text(countdownText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .modifier(GlassButtonCompatInternal())
        .sheet(isPresented: $isShowingSheet) {
            BoostsSheet()
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var hasActiveScoreBoost: Bool {
        GameStore.ScoreBoostTierID.allCases.contains { gameStore.isScoreBoostActive(for: $0) }
    }

    private var hasActivePowerDiscount: Bool {
        GameStore.PowerDiscountTierID.allCases.contains { gameStore.isPowerDiscountActive(for: $0) }
    }

    private var activeCountdownText: String? {
        // Find first active boost and return its countdown
        for tierID in GameStore.ScoreBoostTierID.allCases {
            if gameStore.isScoreBoostActive(for: tierID) {
                let text = gameStore.scoreBoostCountdownText(for: tierID)
                if text != "Ready" { return text }
            }
        }
        for tierID in GameStore.PowerDiscountTierID.allCases {
            if gameStore.isPowerDiscountActive(for: tierID) {
                let text = gameStore.powerDiscountCountdownText(for: tierID)
                if text != "Ready" { return text }
            }
        }
        return nil
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if hasActiveScoreBoost { parts.append("Score boost active") }
        if hasActivePowerDiscount { parts.append("Power discount active") }
        if parts.isEmpty { parts.append("No active boosts") }
        parts.append("Tap to open boosts menu")
        return parts.joined(separator: ". ")
    }
}

// Internal glass button modifier to avoid dependency on HUDTopBar's private modifier
private struct GlassButtonCompatInternal: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

#Preview("Boosts Sheet") {
    let gameStore = GameStore()

    return BoostsSheet()
        .environment(\.gameStore, gameStore)
        .environment(\.toastManager, ToastManager())
}

#Preview("Boost Status Button") {
    let gameStore = GameStore()

    return ZStack {
        Color.black.ignoresSafeArea()
        BoostStatusButton()
    }
    .environment(\.gameStore, gameStore)
}
