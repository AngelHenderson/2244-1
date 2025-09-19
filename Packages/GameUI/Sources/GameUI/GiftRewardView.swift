import SwiftUI
import GameApp

#if canImport(SwiftUI)
extension View {
    @ViewBuilder
    func glassIfAvailableCard() -> some View {
        if #available(iOS 26.0, *) {
            // Prefer the new glass effect when available
            self.glassEffect()
        } else if #available(iOS 15.0, *) {
            // Fallback to a material background for a similar look
            self.background(.ultraThinMaterial)
        } else {
            self
        }
    }
}
#endif

public struct GiftRewardView: View {
    let giftReward: GiftReward
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var petBounce = false

    public init(giftReward: GiftReward, onDismiss: @escaping () -> Void) {
        self.giftReward = giftReward
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Group {
                if #available(iOS 26.0, *) {
                    Color.clear
                        .ignoresSafeArea()
                        .glassEffect()
                } else if #available(iOS 15.0, *) {
                    Color.clear
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                } else {
                    Color.clear
                        .ignoresSafeArea()
                }
            }

            VStack(spacing: 0) {
                // Main content card
                VStack(spacing: 24) {
                    // Cute pet character
                    ZStack {
                        // Gradient background for pet
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.1),
                                Color.purple.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())

                        // Pet character - using a combination of shapes to create cute creature
                        VStack(spacing: -10) {
                            // Ears
                            HStack(spacing: 30) {
                                Ellipse()
                                    .fill(Color.orange.opacity(0.8))
                                    .frame(width: 20, height: 35)
                                    .rotationEffect(.degrees(-20))

                                Ellipse()
                                    .fill(Color.orange.opacity(0.8))
                                    .frame(width: 20, height: 35)
                                    .rotationEffect(.degrees(20))
                            }

                            // Head
                            Circle()
                                .fill(Color.orange.opacity(0.9))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    VStack(spacing: 4) {
                                        // Eyes
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 8, height: 8)
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 8, height: 8)
                                        }

                                        // Nose
                                        Circle()
                                            .fill(Color.pink)
                                            .frame(width: 4, height: 4)
                                    }
                                    .offset(y: -5)
                                }

                            // Body
                            Ellipse()
                                .fill(Color.orange.opacity(0.8))
                                .frame(width: 60, height: 80)
                                .overlay {
                                    // Belly
                                    Ellipse()
                                        .fill(Color.orange.opacity(0.6))
                                        .frame(width: 35, height: 50)
                                }
                        }
                        .scaleEffect(petBounce ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: petBounce)
                    }

                    // Title - only show "You Won a Gift!" if from glass shatter
                    Text(giftReward.isFromGlassShatter ? "You Won a Gift!" : "Reward!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    // Subtitle based on gift type
                    Text(giftReward.message)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Reward display
                    HStack(spacing: 16) {
                        ForEach(giftReward.items, id: \.type) { item in
                            VStack(spacing: 8) {
                                Image(systemName: iconName(for: item))
                                    .font(.largeTitle)
                                    .foregroundStyle(color(for: item))

                                Text("\(item.amount)")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)

                                Text(name(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .glassIfAvailableCard()
                        }
                    }

                    // Pagination dots (like in mockup)
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index == 0 ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.top, 8)

                    // Dismiss button
                    Button("Awesome!") {
                        onDismiss()
                    }
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 25)
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(32)
                .glassIfAvailableCard()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .scaleEffect(showContent ? 1.0 : 0.8)
                .opacity(showContent ? 1.0 : 0.0)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.0),
                    value: showContent
                )
            }
            .padding()
        }
        .onAppear {
            showContent = true
            petBounce = true
        }
    }

    private func iconName(for item: GiftRewardItem) -> String {
        switch item.type {
        case .hammer: return "hammer.fill"
        case .magnet: return "magnet"
        case .gems: return "diamond.fill"
        case .swap: return "arrow.2.squarepath"
        case .undo: return "arrow.uturn.backward.circle.fill"
        }
    }

    private func color(for item: GiftRewardItem) -> Color {
        switch item.type {
        case .hammer: return .orange
        case .magnet: return .red
        case .gems: return .cyan
        case .swap: return .green
        case .undo: return .purple
        }
    }

    private func name(for item: GiftRewardItem) -> String {
        switch item.type {
        case .hammer: return item.amount == 1 ? "Hammer" : "Hammers"
        case .magnet: return item.amount == 1 ? "Magnet" : "Magnets"
        case .gems: return item.amount == 1 ? "Gem" : "Gems"
        case .swap: return item.amount == 1 ? "Swap" : "Swaps"
        case .undo: return item.amount == 1 ? "Undo" : "Undos"
        }
    }
}

// MARK: - SwiftUI Previews

#Preview("Single Item Gift") {
    GiftRewardView(
        giftReward: GiftReward(
            message: "A helpful hammer appeared!",
            items: [GiftRewardItem(type: .hammer, amount: 1)]
        ),
        onDismiss: { print("Preview dismiss") }
    )
}

#Preview("Multiple Items Gift") {
    GiftRewardView(
        giftReward: GiftReward(
            message: "Multiple goodies appeared!",
            items: [
                GiftRewardItem(type: .gems, amount: 5),
                GiftRewardItem(type: .hammer, amount: 2),
                GiftRewardItem(type: .magnet, amount: 1)
            ]
        ),
        onDismiss: { print("Preview dismiss") }
    )
}

#Preview("Gems Gift") {
    GiftRewardView(
        giftReward: GiftReward(
            message: "Some magical gems appeared!",
            items: [GiftRewardItem(type: .gems, amount: 10)]
        ),
        onDismiss: { print("Preview dismiss") }
    )
}

#Preview("Power-up Bundle") {
    GiftRewardView(
        giftReward: GiftReward(
            message: "Amazing power-up bundle!",
            items: [
                GiftRewardItem(type: .hammer, amount: 3),
                GiftRewardItem(type: .swap, amount: 2),
                GiftRewardItem(type: .undo, amount: 5),
                GiftRewardItem(type: .magnet, amount: 1)
            ]
        ),
        onDismiss: { print("Preview dismiss") }
    )
}

#Preview("Dark Mode") {
    GiftRewardView(
        giftReward: GiftReward(
            message: "Some magical gems appeared!",
            items: [
                GiftRewardItem(type: .gems, amount: 15),
                GiftRewardItem(type: .hammer, amount: 1)
            ]
        ),
        onDismiss: { print("Preview dismiss") }
    )
    .preferredColorScheme(.dark)
}

#Preview("Random Reward") {
    GiftRewardView(
        giftReward: GiftReward.randomReward(),
        onDismiss: { print("Preview dismiss") }
    )
}

