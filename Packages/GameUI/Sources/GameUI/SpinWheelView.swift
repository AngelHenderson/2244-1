#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import SwiftUI
import Observation
import GameApp
import GameServices

// MARK: - View

@MainActor
public struct SpinWheelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wheelEngine) private var engine
    @Environment(\.gameStore) private var gameStore
    @Environment(\.hapticsService) private var haptics
    @Environment(HomeState.self) private var homeState
    @Environment(\.spinWheelState) private var spinState
    @Environment(\.audio) private var audioService
    @State private var showReward = false
    @State private var rewardMessage = ""
    @State private var purchaseFeedback: String?
    @State private var showShopFromGems = false
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var slotReady: Bool { spinState.slotAvailable(on: now) }
    private var bonusReady: Bool { spinState.bonusSpins > 0 }
    private var canSpin: Bool { (slotReady || bonusReady) && !engine.isSpinning }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    BackgroundGradient()
                    VStack(spacing: 16) {
                        header
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 24) {
                                wheelRow
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 24)
                                
                                availabilityCard
                                    .padding(.horizontal, 24)
                                
                                HStack(spacing: 12) {
                                    purchaseOptions
                                    spinButton
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height * 0.9, alignment: .top)
                            .background(
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .fill(Color.black.opacity(0.15))
                                    .padding(.horizontal, 12)
                            )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        MultiplierInventoryCard(spinState: spinState, now: now)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 16)
                }
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onReceive(timer) { date in
            Task { @MainActor in
                now = date
                spinState.refresh(now: date)
            }
        }
        .alert("🎉 Congratulations!", isPresented: $showReward) {
            Button("Collect", role: .cancel) {
                showReward = false
            }
        } message: {
            Text(rewardMessage)
        }
        .onAppear {
            // Set up tick sound callback for wheel
            engine.onTick = { [audioService] in
                Task { await audioService.playSfx(name: "tick") }
            }
        }
        .adaptiveSheet(isPresented: $showShopFromGems) {
            ShopView(initialTab: .gems)
        }
    }
    
    private var header: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassOrMaterialBackground(cornerRadius: 22)
            }
            
            Spacer()

            Text("SPIN")
                .font(.avenirNext(size: GameFonts.title1Size, weight: .bold))
                .foregroundStyle(.white)

            Spacer()
            
            GemBalancePill()
        }
    }
    
    private var wheelRow: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.24))
                
                WheelFace(segments: engine.segments)
                    .rotationEffect(.radians(Double(engine.angle)))

                WheelLights(count: max(engine.segments.count, 1), segments: engine.segments)
                    .rotationEffect(.radians(Double(engine.angle)))
                
                LocationPinShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.85, blue: 0.4), Color(red: 0.2, green: 0.65, blue: 0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        LocationPinShape()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 12, height: 12)
                            .offset(y: -18)
                    )
                    .frame(width: 32, height: 48)
                    .rotationEffect(.radians(Double(engine.tickerDeflection)), anchor: .top)
                    .offset(y: -225)
                    .shadow(color: Color(red: 0.2, green: 0.5, blue: 0.2).opacity(0.6), radius: 6, x: 0, y: 4)
                
                Circle()
                    .fill(.ultraThickMaterial)
                    .frame(width: 70, height: 70)
                    .shadow(color: .black.opacity(0.4), radius: 8)
                
                if let active = spinState.activeMultiplier {
                    ActiveMultiplierBadge(active: active, countdown: spinState.formattedActiveMultiplierCountdown(now: now))
                } else {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 2)
                        .frame(width: 90, height: 90)
                }
            }
            .frame(width: 400, height: 400)
            .padding(.top, 50)
        }
    }
    
    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Next spin", systemImage: "clock.fill")
                    .font(.avenirNext(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(spinState.formattedCountdown(now: now))
                    .font(.avenirNext(size: 18, weight: .bold))
                    .foregroundStyle(slotReady ? .green : .white)
            }

            if bonusReady {
                Text("Bonus spins available: \(spinState.bonusSpins)")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.avenirNext(size: 16, weight: .medium))
            } else if slotReady {
                Text("Ready now - tap Spin to claim this window.")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.avenirNext(size: 16, weight: .medium))
            } else {
                Text("Windows reset every 12a / 4a / 8a / 12p / 4p / 8p.")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.avenirNext(size: 14, weight: .medium))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    private var purchaseOptions: some View {
        VStack(spacing: 8) {
            purchaseButton(title: "1 Spin", cost: 2000, grant: 1)
            purchaseButton(title: "3 Spins", cost: 10000, grant: 3)
        }
    }
    
    private func purchaseButton(title: String, cost: Int, grant: Int) -> some View {
        Button {
            purchaseBonusSpins(count: grant, cost: cost)
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(.avenirNext(size: 13, weight: .bold))
                Text("\(cost) gems")
                    .font(.avenirNext(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 120, height: 46)
            .foregroundStyle(.white)
            .glassOrMaterialBackground(cornerRadius: 20)
            .opacity(homeState.gems >= cost ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(homeState.gems < cost)
    }
    
    private var spinButton: some View {
        Button(action: startSpin) {
            Text(canSpin ? "SPIN" : "WAIT")
                .font(.avenirNext(size: 24, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.white)
                .glassOrMaterialBackground(cornerRadius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: canSpin ? [Color(red: 0.29, green: 0.96, blue: 0.52), Color(red: 0.17, green: 0.76, blue: 0.99)]
                                                 : [Color.gray.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        }
        .frame(height: 100)
        .opacity(canSpin ? 1.0 : 0.6)
        .disabled(!canSpin)
    }
    
    private func startSpin() {
        guard let _ = spinState.beginSpin(now: now) else { return }
        gameStore.registerSpinUse()
        haptics.mediumImpact()
        engine.spin { segment in
            handleWinning(segment: segment)
        }
    }
    
    private func purchaseBonusSpins(count: Int, cost: Int) {
        guard homeState.gems >= cost else {
            purchaseFeedback = "Need \(cost) gems."
            return
        }
        homeState.spendGems(cost)
        spinState.addBonusSpins(count)
        haptics.success()
        purchaseFeedback = "Bought \(count) bonus spin\(count == 1 ? "" : "s")!"
        gameStore.achievementEvaluator?.onSpinPurchased(count: count)
    }
    
    private func handleWinning(segment: WheelSegment) {
        Task { @MainActor in
            let (message, powerupCount) = applyReward(segment.reward)
            haptics.success()
            rewardMessage = message
            showReward = true
            // Track powerups collected for achievement (count = number of powerups won)
            if powerupCount > 0 {
                gameStore.achievementEvaluator?.onWheelCollected(count: powerupCount)
            }
        }
    }

    /// Returns (message, powerupCount) - powerupCount is the number of powerups collected (excludes gems)
    private func applyReward(_ reward: WheelReward, isGiftBox: Bool = false) -> (String, Int) {
        let multiplier = spinState.activeMultiplier?.tier.multiplierValue ?? 1

        switch reward.type {
        case .gems:
            let amount = reward.amount * multiplier
            grantGems(amount)
            let message = isGiftBox ? "Gift Box surprise! You won \(amount) gems! 💎" : "You won \(amount) gems! 💎"
            return (message, 0) // Gems don't count as powerups

        case .hammers:
            gameStore.addPowerUp("hammer", count: reward.amount)
            let message = isGiftBox ? "Gift Box surprise! You won \(reward.amount) hammer\(pluralSuffix(for: reward.amount))! 🔨"
                                    : "You won \(reward.amount) hammer\(pluralSuffix(for: reward.amount))! 🔨"
            return (message, reward.amount)

        case .magnets:
            gameStore.addPowerUp("magnet", count: reward.amount)
            let message = isGiftBox ? "Gift Box surprise! You won \(reward.amount) MegaMerge\(pluralSuffix(for: reward.amount))! 🧲"
                                    : "You won \(reward.amount) MegaMerge\(pluralSuffix(for: reward.amount))! 🧲"
            return (message, reward.amount)

        case .swap:
            gameStore.addPowerUp("swap", count: reward.amount)
            let message = isGiftBox ? "Gift Box surprise! You won \(reward.amount) swap\(pluralSuffix(for: reward.amount))! 🔁"
                                    : "You won \(reward.amount) swap\(pluralSuffix(for: reward.amount))! 🔁"
            return (message, reward.amount)

        case .spin:
            spinState.addBonusSpins(reward.amount)
            let base = reward.amount == 1 ? "Bonus spin added! 🎡" : "\(reward.amount) bonus spins added! 🎡"
            let message = isGiftBox ? "Gift Box surprise! \(base)" : base
            return (message, reward.amount) // Spins count as powerups

        case .multiplier(let tier):
            spinState.addMultiplier(tier)
            let base = "You banked a \(tier.displayName) boost for 24 hours!"
            let message = isGiftBox ? "Gift Box surprise! \(base)" : base
            return (message, 1) // Multiplier counts as 1 powerup

        case .giftBox:
            return applyGiftBoxRewards()
        }
    }

    private func applyGiftBoxRewards() -> (String, Int) {
        let isMultiReward = Bool.random()

        if isMultiReward {
            // 50%: Multiple rewards (2-3 different rewards)
            let rewards = randomMultipleGiftRewards()
            var messages: [String] = []
            var totalPowerups = 0

            for reward in rewards {
                let (msg, count) = applySingleReward(reward)
                messages.append(msg)
                totalPowerups += count
            }

            let combined = messages.joined(separator: ", ")
            return ("Gift Box Jackpot! 🎁 \(combined)", totalPowerups)
        } else {
            // 50%: Single reward
            let reward = randomSingleGiftReward()
            let (msg, count) = applySingleReward(reward)
            return ("Gift Box surprise! \(msg)", count)
        }
    }

    private func applySingleReward(_ reward: WheelReward) -> (String, Int) {
        let multiplier = spinState.activeMultiplier?.tier.multiplierValue ?? 1

        switch reward.type {
        case .gems:
            let amount = reward.amount * multiplier
            grantGems(amount)
            return ("\(amount) Gems 💎", 0)
        case .hammers:
            gameStore.addPowerUp("hammer", count: reward.amount)
            return ("\(reward.amount) Hammer\(pluralSuffix(for: reward.amount)) 🔨", reward.amount)
        case .magnets:
            gameStore.addPowerUp("magnet", count: reward.amount)
            return ("\(reward.amount) MegaMerge\(pluralSuffix(for: reward.amount)) 🧲", reward.amount)
        case .swap:
            gameStore.addPowerUp("swap", count: reward.amount)
            return ("\(reward.amount) Swap\(pluralSuffix(for: reward.amount)) 🔁", reward.amount)
        case .spin:
            spinState.addBonusSpins(reward.amount)
            return ("\(reward.amount) Spin\(pluralSuffix(for: reward.amount)) 🎡", reward.amount)
        case .multiplier(let tier):
            spinState.addMultiplier(tier)
            return ("\(tier.displayName) Boost ⚡", 1)
        case .giftBox:
            return ("", 0)
        }
    }

    private func randomSingleGiftReward() -> WheelReward {
        let options: [WheelReward] = [
            .init(type: .gems, amount: 2000),
            .init(type: .magnets, amount: 2),
            .init(type: .hammers, amount: 3),
            .init(type: .swap, amount: 2),
            .init(type: .spin, amount: 2),
            .init(type: .multiplier(.fourX), amount: 1),
            .init(type: .multiplier(.threeX), amount: 1)
        ]
        return options.randomElement() ?? options[0]
    }

    private func randomMultipleGiftRewards() -> [WheelReward] {
        let allOptions: [WheelReward] = [
            .init(type: .gems, amount: 300),
            .init(type: .gems, amount: 500),
            .init(type: .magnets, amount: 1),
            .init(type: .hammers, amount: 2),
            .init(type: .swap, amount: 1),
            .init(type: .spin, amount: 1),
            .init(type: .multiplier(.twoX), amount: 1),
            .init(type: .multiplier(.threeX), amount: 1)
        ]

        var selected: [WheelReward] = []
        var usedTypes: Set<String> = []
        let rewardCount = Int.random(in: 2...3)

        var shuffled = allOptions.shuffled()
        while selected.count < rewardCount && !shuffled.isEmpty {
            let reward = shuffled.removeFirst()
            let typeKey = rewardTypeKey(reward.type)
            if !usedTypes.contains(typeKey) {
                usedTypes.insert(typeKey)
                selected.append(reward)
            }
        }

        return selected
    }

    private func rewardTypeKey(_ type: WheelReward.RewardType) -> String {
        switch type {
        case .gems: return "gems"
        case .hammers: return "hammers"
        case .magnets: return "magnets"
        case .swap: return "swap"
        case .spin: return "spin"
        case .multiplier(_): return "multiplier"
        case .giftBox: return "giftBox"
        }
    }
    
    private func grantGems(_ amount: Int) {
        homeState.addGems(amount)
        gameStore.addCoins(amount)
        gameStore.saveProgressToStore()
    }
    
    private func pluralSuffix(for amount: Int) -> String {
        amount == 1 ? "" : "s"
    }
}

#if canImport(UIKit)
private func segmentImage(named name: String) -> Image? {
    if let uiImage = UIImage(named: name, in: .module, compatibleWith: nil) {
        return Image(uiImage: uiImage).renderingMode(.original)
    }
    if let path = Bundle.module.path(forResource: name, ofType: "png"),
       let uiImage = UIImage(contentsOfFile: path) {
        return Image(uiImage: uiImage).renderingMode(.original)
    }
    return nil
}
#elseif canImport(AppKit)
private func segmentImage(named name: String) -> Image? {
    if let nsImage = Bundle.module.image(forResource: NSImage.Name(name)) {
        return Image(nsImage: nsImage)
    }
    if let path = Bundle.module.path(forResource: name, ofType: "png"),
       let nsImage = NSImage(contentsOfFile: path) {
        return Image(nsImage: nsImage)
    }
    return nil
}
#else
private func segmentImage(named name: String) -> Image? { nil }
#endif

// MARK: - Background

private struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.03, blue: 0.11),
                Color(red: 0.09, green: 0.07, blue: 0.21),
                Color(red: 0.05, green: 0.06, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// GemBalancePill is now a shared public component in Components/GemBalancePill.swift

// MARK: - Inventory Card

private struct MultiplierInventoryCard: View {
    @Environment(\.gameStore) private var gameStore
    @Bindable var spinState: SpinWheelState
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Boost Inventory")
                .font(.avenirNext(size: 16, weight: .bold))
                .foregroundStyle(.white)

            ForEach(SpinWheelState.MultiplierTier.allCases, id: \.self) { tier in
                let canActivate = spinState.count(for: tier) > 0 && spinState.activeMultiplier == nil
                let durationHours = Int(tier.duration / 3600)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(tier.displayName) for \(durationHours)h")
                            .font(.avenirNext(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Stacks until you use it")
                            .font(.avenirNext(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("×\(spinState.count(for: tier))")
                        .font(.avenirNext(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, alignment: .trailing)
                    Button("Use") {
                        if spinState.activateMultiplier(tier, now: now) {
                            switch tier {
                            case .twoX:
                                gameStore.achievementEvaluator?.onBoost2xUsed()
                            case .threeX:
                                gameStore.achievementEvaluator?.onBoost3xUsed()
                            case .fourX:
                                gameStore.achievementEvaluator?.onBoost4xUsed()
                            }
                        }
                    }
                    .font(.avenirNext(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundColor(.white)
                    .glassOrMaterialBackground(cornerRadius: 12)
                    .opacity(canActivate ? 1.0 : 0.5)
                    .disabled(!canActivate)
                }
            }

            if let active = spinState.activeMultiplier {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active: \(active.tier.displayName)")
                        .font(.avenirNext(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(spinState.formattedActiveMultiplierCountdown(now: now))
                        .font(.avenirNext(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Wheel visuals

struct WheelFace: View {
    let segments: [WheelSegment]

    // Calculate total weight for proportional sizing
    private var totalWeight: Int {
        segments.reduce(0) { $0 + $1.weight }
    }

    // Returns the angular span (in radians) for a segment at the given index
    private func segmentSpan(at index: Int) -> CGFloat {
        let weight = segments[index].weight
        return CGFloat(weight) / CGFloat(totalWeight) * 2 * .pi
    }

    // Returns the starting angle (in radians) for a segment at the given index
    private func segmentStartAngle(at index: Int) -> CGFloat {
        var startAngle: CGFloat = 0
        for i in 0..<index {
            startAngle += segmentSpan(at: i)
        }
        return startAngle
    }

    // Returns the center angle (in radians) for a segment at the given index
    private func segmentCenterAngle(at index: Int) -> CGFloat {
        segmentStartAngle(at: index) + segmentSpan(at: index) / 2
    }

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let radius = min(rect.width, rect.height) / 2
            ZStack {
                // Draw segment slices with weighted sizes
                ForEach(segments.indices, id: \.self) { i in
                    let start = segmentStartAngle(at: i)
                    let end = start + segmentSpan(at: i)
                    WheelSectorShape(start: start, end: end)
                        .fill(segments[i].color)
                        .overlay(
                            WheelSectorShape(start: start, end: end)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }

                // Draw labels at segment centers
                ForEach(segments.indices, id: \.self) { i in
                    let centerAngle = segmentCenterAngle(at: i)
                    let r = radius * 0.62
                    let x = rect.midX + r * sin(centerAngle)
                    let y = rect.midY - r * cos(centerAngle)

                    RadialLabel(angle: centerAngle - (.pi / 2)) {
                        HStack(spacing: 6) {
                            if let assetName = segments[i].iconAssetName,
                               let bundleImage = segmentImage(named: assetName) {
                                bundleImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Text(segments[i].icon)
                                    .font(.avenirNext(size: 18, weight: .regular))
                            }
                            Text(segments[i].title)
                                .font(.avenirNext(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .position(x: x, y: y)
                }

                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 6)

                WeightedTicks(segments: segments)
                    .stroke(Color.white.opacity(0.18), style: .init(lineWidth: 2, lineCap: .round))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WheelSectorShape: Shape {
    var start: CGFloat
    var end: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: center)
        p.addArc(center: center,
                 radius: radius,
                 startAngle: .radians(Double(-.pi/2 + start)),
                 endAngle: .radians(Double(-.pi/2 + end)),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct Ticks: Shape {
    let count: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.93
        let span = 2 * .pi / CGFloat(max(count, 1))
        for k in 0..<count {
            let a = CGFloat(k) * span
            let sx = center.x + inner * sin(a)
            let sy = center.y - inner * cos(a)
            let ex = center.x + outer * sin(a)
            let ey = center.y - outer * cos(a)
            p.move(to: CGPoint(x: sx, y: sy))
            p.addLine(to: CGPoint(x: ex, y: ey))
        }
        return p
    }
}

struct WeightedTicks: Shape {
    let segments: [WheelSegment]

    private var totalWeight: Int {
        segments.reduce(0) { $0 + $1.weight }
    }

    private func segmentSpan(at index: Int) -> CGFloat {
        let weight = segments[index].weight
        return CGFloat(weight) / CGFloat(totalWeight) * 2 * .pi
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.93

        var angle: CGFloat = 0
        for i in 0..<segments.count {
            let sx = center.x + inner * sin(angle)
            let sy = center.y - inner * cos(angle)
            let ex = center.x + outer * sin(angle)
            let ey = center.y - outer * cos(angle)
            p.move(to: CGPoint(x: sx, y: sy))
            p.addLine(to: CGPoint(x: ex, y: ey))
            angle += segmentSpan(at: i)
        }
        return p
    }
}

struct WheelLights: View {
    let count: Int
    var segments: [WheelSegment]? = nil

    private var totalWeight: Int {
        guard let segments = segments else { return count }
        return segments.reduce(0) { $0 + $1.weight }
    }

    private func segmentSpan(at index: Int) -> CGFloat {
        guard let segments = segments else {
            return 2 * .pi / CGFloat(max(count, 1))
        }
        let weight = segments[index].weight
        return CGFloat(weight) / CGFloat(totalWeight) * 2 * .pi
    }

    private func dividerAngle(at index: Int) -> CGFloat {
        guard segments != nil else {
            return 2 * .pi * CGFloat(index) / CGFloat(max(count, 1))
        }
        var angle: CGFloat = 0
        for i in 0..<index {
            angle += segmentSpan(at: i)
        }
        return angle
    }

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let radius = min(rect.width, rect.height) / 2 - 10
            let segmentCount = segments?.count ?? count
            ForEach(0..<max(segmentCount, 1), id: \.self) { index in
                let angle = dividerAngle(at: index)
                let x = rect.midX + radius * sin(angle)
                let y = rect.midY - radius * cos(angle)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 12, height: 12)
                    .position(x: x, y: y)
            }
        }
    }
}

private struct RadialLabel<Content: View>: View {
    let angle: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .rotationEffect(.radians(Double(angle)))
    }
}

struct PegShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: w, y: rect.height))
        p.closeSubpath()
        return p
    }
}

struct LocationPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let circleRadius = w / 2
        let circleCenter = CGPoint(x: w / 2, y: circleRadius)

        // Start at the bottom point
        p.move(to: CGPoint(x: w / 2, y: h))

        // Draw left curve up to circle
        p.addQuadCurve(
            to: CGPoint(x: 0, y: circleRadius),
            control: CGPoint(x: 0, y: h * 0.5)
        )

        // Draw the circle arc (top half)
        p.addArc(
            center: circleCenter,
            radius: circleRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Draw right curve down to point
        p.addQuadCurve(
            to: CGPoint(x: w / 2, y: h),
            control: CGPoint(x: w, y: h * 0.5)
        )

        p.closeSubpath()
        return p
    }
}

struct SidePegShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let attachY = rect.midY
        p.move(to: CGPoint(x: rect.maxX, y: attachY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct ActiveMultiplierBadge: View {
    let active: SpinWheelState.ActiveMultiplier
    let countdown: String
    
    private var colors: [Color] {
        switch active.tier {
        case .twoX:
            return [Color(red: 0.31, green: 0.94, blue: 0.63), Color(red: 0.15, green: 0.74, blue: 0.96)]
        case .threeX:
            return [Color(red: 0.97, green: 0.72, blue: 0.24), Color(red: 0.99, green: 0.48, blue: 0.24)]
        case .fourX:
            return [Color(red: 0.94, green: 0.34, blue: 0.70), Color(red: 0.53, green: 0.23, blue: 0.91)]
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(active.tier.displayName)
                .font(.avenirNext(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(countdown)
                .font(.avenirNext(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(20)
        .background(
            Circle().fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
        .shadow(color: colors.last?.opacity(0.4) ?? .black.opacity(0.4), radius: 10, x: 0, y: 6)
    }
}

#Preview {
    SpinWheelView()
        .environment(\.wheelEngine, WheelEngine())
}
