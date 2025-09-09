import SwiftUI
import GameApp

// MARK: - View

public struct SpinWheelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wheelEngine) private var engine
    @Environment(\.hapticsService) private var haptics
    @State private var hasSpun = false
    @State private var showReward = false
    @State private var rewardMessage = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Title
                    Text("Spin the Wheel")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    // Wheel container
                    ZStack {
                        // Wheel
                        WheelFace(segments: engine.segments)
                            .rotationEffect(.radians(Double(engine.angle)))
                            .shadow(radius: 4)
                        
                        // Peg/ticker at top (points down)
                        PegShape()
                            .fill(.ultraThickMaterial)
                            .overlay(PegShape().stroke(Color.black.opacity(0.2), lineWidth: 1.5))
                            .frame(width: 22, height: 70)
                            .rotationEffect(.radians(Double(engine.tickerDeflection)), anchor: .top)
                            .offset(y: -150)
                            .shadow(radius: 3)
                        
                        // Center hub
                        Circle()
                            .fill(.regularMaterial)
                            .frame(width: 52, height: 52)
                            .overlay(Circle().stroke(.black.opacity(0.2), lineWidth: 1.5))
                    }
                    .frame(width: 320, height: 320)
                    .accessibilityLabel(Text("Spin wheel"))
                    
                    // Selected segment display
                    VStack(spacing: 8) {
                        Text("Current Prize")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        HStack(spacing: 12) {
                            Text(engine.segments[engine.highlightedIndex].icon)
                                .font(.system(size: 44))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(engine.segments[engine.highlightedIndex].title)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text(engine.segments[engine.highlightedIndex].subtitle)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(engine.segments[engine.highlightedIndex].color.opacity(0.9))
                        )
                        .animation(.easeInOut(duration: 0.3), value: engine.highlightedIndex)
                    }
                    
                    Spacer()
                    
                    // Controls
                    HStack(spacing: 20) {
                        Button {
                            hasSpun = true
                            haptics.mediumImpact()
                            engine.spin { segment in
                                // Handle the result
                                handleWinning(segment: segment)
                            }
                        } label: {
                            Label("SPIN", systemImage: "arrow.2.circlepath.circle.fill")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(hasSpun ? AnyShapeStyle(Color.gray) : AnyShapeStyle(LinearGradient(
                                            colors: [Color.green, Color.blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )))
                                )
                                .foregroundStyle(.white)
                                .shadow(radius: hasSpun ? 1 : 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.isSpinning || hasSpun)
                        
                        Button(role: .cancel) {
                            if engine.isSpinning {
                                engine.stop()
                            } else {
                                dismiss()
                            }
                        } label: {
                            Label(engine.isSpinning ? "STOP" : "CLOSE", 
                                  systemImage: engine.isSpinning ? "stop.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .frame(maxWidth: 140)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.9))
                                )
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .alert("🎉 Congratulations!", isPresented: $showReward) {
            Button("Collect", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(rewardMessage)
        }
    }
    
    private func handleWinning(segment: WheelSegment) {
        // Process the reward based on the segment
        let reward = segment.reward
        
        Task { @MainActor in
            // Apply the reward
            switch reward.type {
            case .gems:
                // Add gems to user's balance
                if let homeState = try? await HomeState.shared() {
                    homeState.addGems(reward.amount)
                }
                rewardMessage = "You won \(reward.amount) gems! 💎"
                
            case .hammers:
                // Add hammers to inventory
                rewardMessage = "You won \(reward.amount) hammer\(reward.amount == 1 ? "" : "s")! 🔨"
                
            case .magnets:
                // Add magnets to inventory
                rewardMessage = "You won \(reward.amount) magnet\(reward.amount == 1 ? "" : "s")! 🧲"
                
            case .spin:
                // Award extra spin
                rewardMessage = "You won an extra spin! 🎰"
                hasSpun = false // Allow another spin
                return // Don't show alert for extra spin
            }
            
            haptics.success()
            showReward = true
        }
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
                // Colored sectors (centered so index 0's center is at top peg)
                ForEach(segments.indices, id: \.self) { i in
                    let n = max(segments.count, 1)
                    let span = 2 * .pi / CGFloat(n)
                    let start = CGFloat(i) * span - span/2
                    let end = start + span
                    WheelSectorShape(start: start, end: end)
                        .fill(segments[i].color.gradient)
                        .overlay(
                            WheelSectorShape(start: start, end: end)
                                .stroke(.white.opacity(0.8), lineWidth: 1.5)
                        )
                }
                
                // Labels
                ForEach(segments.indices, id: \.self) { i in
                    let n = max(segments.count, 1)
                    let span = 2 * .pi / CGFloat(n)
                    let centerAngle = CGFloat(i) * span
                    let r = radius * 0.65
                    let x = rect.midX + r * sin(centerAngle)
                    let y = rect.midY - r * cos(centerAngle)
                    VStack(spacing: 2) {
                        Text(segments[i].icon)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text(segments[i].shortLabel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .position(x: x, y: y)
                    .rotationEffect(.radians(Double(centerAngle)))
                }
                
                // Rim + ticks
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .black.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                Ticks(count: segments.count)
                    .stroke(.black.opacity(0.3), style: .init(lineWidth: 2.5, lineCap: .round))
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

struct PegShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Triangle pointing down, anchored at top
        var p = Path()
        let w = rect.width
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: w, y: rect.height))
        p.closeSubpath()
        return p
    }
}

#Preview {
    SpinWheelView()
        .environment(\.wheelEngine, WheelEngine())
}