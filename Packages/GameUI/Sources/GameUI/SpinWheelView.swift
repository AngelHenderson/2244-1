import SwiftUI
import Observation
import GameApp

// MARK: - View

@MainActor
public struct SpinWheelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wheelEngine) private var engine
    @Environment(\.hapticsService) private var haptics
    @Environment(HomeState.self) private var homeState
    
    @State private var spinState = SpinWheelState()
    @State private var showReward = false
    @State private var rewardMessage = ""
    @State private var purchaseFeedback: String?
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var slotReady: Bool { spinState.slotAvailable(on: now) }
    private var bonusReady: Bool { spinState.bonusSpins > 0 }
    private var canSpin: Bool { (slotReady || bonusReady) && !engine.isSpinning }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient()
                VStack(spacing: 16) {
                    header
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            wheelSection
                            availabilityCard
                            purchaseOptions
                            spinButton
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    MultiplierInventoryCard(spinState: spinState, now: now)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .padding(.top, 12)
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
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            
            Spacer()
            
            Text("SPIN")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Spacer()
            
            GemBalancePill(gems: homeState.gems)
        }
    }
    
    private var wheelSection: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.cyan.opacity(0.9), .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 140, height: 38)
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.white)
                        Text("2X BONUS")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                )
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.13, green: 0.14, blue: 0.33), Color(red: 0.05, green: 0.06, blue: 0.14)],
                            center: .center,
                            startRadius: 40,
                            endRadius: 170
                        )
                    )
                    .shadow(color: .black.opacity(0.6), radius: 16, x: 0, y: 12)
                
                WheelFace(segments: engine.segments)
                    .rotationEffect(.radians(Double(engine.angle)))
                
                WheelLights(count: max(engine.segments.count, 1))
                
                PegShape()
                    .fill(.ultraThinMaterial)
                    .overlay(PegShape().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
                    .frame(width: 28, height: 90)
                    .rotationEffect(.radians(Double(engine.tickerDeflection)), anchor: .top)
                    .offset(y: -170)
                    .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 4)
                
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
            .frame(width: 340, height: 340)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Next spin", systemImage: "clock.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(spinState.formattedCountdown(now: now))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(slotReady ? .green : .white)
            }
            
            if bonusReady {
                Text("Bonus spins available: \(spinState.bonusSpins)")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            } else if slotReady {
                Text("Ready now - tap Spin to claim this window.")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
            } else {
                Text("Windows reset every 12a / 4a / 8a / 12p / 4p / 8p.")
                    .foregroundStyle(.white.opacity(0.6))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Need more spins?")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            
            HStack(spacing: 12) {
                purchaseButton(title: "1 Free Spin", cost: 2000, grant: 1)
                purchaseButton(title: "3 Free Spins", cost: 10000, grant: 3)
            }
            
            if let feedback = purchaseFeedback {
                Text(feedback)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private func purchaseButton(title: String, cost: Int, grant: Int) -> some View {
        Button {
            purchaseBonusSpins(count: grant, cost: cost)
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("\(cost) gems")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(homeState.gems >= cost ? Color.blue : Color.gray.opacity(0.5))
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(homeState.gems < cost)
    }
    
    private var spinButton: some View {
        Button(action: startSpin) {
            Text(canSpin ? "SPIN" : "COME BACK SOON")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: canSpin ? [Color(red: 0.29, green: 0.96, blue: 0.52), Color(red: 0.17, green: 0.76, blue: 0.99)]
                                                 : [Color.gray.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundStyle(.white)
                .shadow(color: canSpin ? Color.black.opacity(0.4) : .clear, radius: 12, y: 8)
        }
        .disabled(!canSpin)
    }
    
    private func startSpin() {
        guard let _ = spinState.beginSpin(now: now) else { return }
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
    }
    
    private func handleWinning(segment: WheelSegment) {
        let reward = segment.reward
        Task { @MainActor in
            switch reward.type {
            case .gems:
                homeState.addGems(reward.amount)
                rewardMessage = "You won \(reward.amount) gems! 💎"
            case .hammers:
                rewardMessage = "You won \(reward.amount) hammer\(pluralSuffix(for: reward.amount))! 🔨"
            case .magnets:
                rewardMessage = "You won \(reward.amount) magnet\(pluralSuffix(for: reward.amount))! 🧲"
            case .swap:
                rewardMessage = "You won \(reward.amount) swap\(pluralSuffix(for: reward.amount))! 🔁"
            case .spin:
                spinState.addBonusSpins(reward.amount)
                rewardMessage = reward.amount == 1 ? "Bonus spin added! 🎡" : "\(reward.amount) bonus spins added! 🎡"
            case .multiplier(let tier):
                spinState.addMultiplier(tier)
                rewardMessage = "You banked a \(tier.displayName) boost for 24 hours!"
            case .giftBox:
                rewardMessage = "Mystery prize! 🎁"
            }
            
            haptics.success()
            showReward = true
        }
    }
    
    private func pluralSuffix(for amount: Int) -> String {
        amount == 1 ? "" : "s"
    }
}

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

private struct GemBalancePill: View {
    let gems: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "diamond.fill")
                .foregroundStyle(.white)
                .font(.system(size: 16, weight: .bold))
            Text(verbatim: String(gems))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.06, green: 0.56, blue: 0.33), in: Capsule())
        .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
    }
}

// MARK: - Inventory Card

private struct MultiplierInventoryCard: View {
    @Bindable var spinState: SpinWheelState
    let now: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Boost Inventory")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            ForEach(SpinWheelState.MultiplierTier.allCases, id: \.self) { tier in
                let canActivate = spinState.count(for: tier) > 0 && spinState.activeMultiplier == nil
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(tier.displayName) for 24h")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Stacks until you use it")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("×\(spinState.count(for: tier))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 36, alignment: .trailing)
                    Button("Use") {
                        _ = spinState.activateMultiplier(tier, now: now)
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(canActivate ? Color.blue : Color.gray.opacity(0.4))
                    )
                    .foregroundColor(.white)
                    .disabled(!canActivate)
                }
            }
            
            if let active = spinState.activeMultiplier {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active: \(active.tier.displayName)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(spinState.formattedActiveMultiplierCountdown(now: now))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
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
    
    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let radius = min(rect.width, rect.height) / 2
            ZStack {
                ForEach(segments.indices, id: \.self) { i in
                    let n = max(segments.count, 1)
                    let span = 2 * .pi / CGFloat(n)
                    let start = CGFloat(i) * span - span / 2
                    let end = start + span
                    WheelSectorShape(start: start, end: end)
                        .fill(
                            LinearGradient(
                                colors: [segments[i].color.opacity(0.9), segments[i].color.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            WheelSectorShape(start: start, end: end)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                
                ForEach(segments.indices, id: \.self) { i in
                    let n = max(segments.count, 1)
                    let span = 2 * .pi / CGFloat(n)
                    let centerAngle = CGFloat(i) * span
                    let r = radius * 0.62
                    let x = rect.midX + r * sin(centerAngle)
                    let y = rect.midY - r * cos(centerAngle)
                    HStack(spacing: 6) {
                        Text(segments[i].icon)
                            .font(.system(size: 20))
                        Text(segments[i].title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .frame(width: 110, alignment: .leading)
                    .position(x: x, y: y)
                    .rotationEffect(.radians(Double(centerAngle)))
                }
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 6
                    )
                Ticks(count: segments.count)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 3, lineCap: .round))
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

struct WheelLights: View {
    let count: Int
    
    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let radius = min(rect.width, rect.height) / 2 - 10
            ForEach(0..<max(count, 1), id: \.self) { index in
                let angle = 2 * .pi * CGFloat(index) / CGFloat(max(count, 1))
                let x = rect.midX + radius * sin(angle)
                let y = rect.midY - radius * cos(angle)
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 12, height: 12)
                    .shadow(color: .white.opacity(0.5), radius: 4, x: 0, y: 0)
                    .position(x: x, y: y)
            }
        }
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(countdown)
                .font(.system(size: 12, weight: .medium, design: .rounded))
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