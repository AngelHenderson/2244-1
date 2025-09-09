import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Model

public struct WheelSegment: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let icon: String
    public let shortLabel: String
    public let color: Color
    public let reward: WheelReward
    
    public init(title: String, subtitle: String, icon: String, shortLabel: String, color: Color, reward: WheelReward) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.shortLabel = shortLabel
        self.color = color
        self.reward = reward
    }
}

public struct WheelReward: Hashable, Sendable {
    public enum RewardType: Sendable {
        case gems
        case hammers
        case magnets
        case spin
    }
    
    public let type: RewardType
    public let amount: Int
    
    public init(type: RewardType, amount: Int) {
        self.type = type
        self.amount = amount
    }
}

@MainActor
@Observable
public final class WheelEngine {
    // Public state observed by the view
    public var angle: CGFloat = 0                // radians, wheel rotation (CCW +)
    public var angularVelocity: CGFloat = 0      // radians / second
    public var isSpinning = false
    public var tickerDeflection: CGFloat = 0     // radians, visual peg bend
    public var segments: [WheelSegment]
    
    // Tunables (feel free to tweak)
    public var airDrag: CGFloat = 0.32           // exponential drag coefficient
    public var tickDampingFast: CGFloat = 0.965  // per-notch damping at high speeds
    public var tickDampingSlow: CGFloat = 0.85   // per-notch damping when almost done
    public var stopSpeedThreshold: CGFloat = 0.12 // rad/s => begin snap
    public var snapSpring = (response: 0.35, damping: 0.75)
    
    // Private
    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    private var haptic = UIImpactFeedbackGenerator(style: .light)
    #endif
    private var lastTimestamp: CFTimeInterval?
    private var onComplete: ((WheelSegment) -> Void)?
    private var animationTimer: Timer?
    
    public init(segments: [WheelSegment]? = nil) {
        self.segments = segments ?? WheelEngine.defaultSegments
        #if canImport(UIKit)
        haptic.prepare()
        #endif
    }
    
    // Spin with randomized initial energy
    public func spin(onComplete: @escaping (WheelSegment) -> Void) {
        guard !isSpinning else { return }
        self.onComplete = onComplete
        #if canImport(UIKit)
        haptic.prepare()
        #endif
        
        // 5.5–8.5 rotations/sec initial => lively, but not crazy
        let rps = Double.random(in: 5.5...8.5)
        angularVelocity = CGFloat(rps * 2.0 * .pi) * (Bool.random() ? 1 : -1)
        isSpinning = true
        startAnimation()
    }
    
    public func stop() {
        isSpinning = false
        angularVelocity = 0
        stopAnimation()
        // Snap to nearest center
        snapToNearestCenter()
    }
    
    // Computed: which segment is currently under the top peg (index)
    public var highlightedIndex: Int {
        let n = max(segments.count, 1)
        let span = 2 * .pi / CGFloat(n)
        let normalized = Self.wrap(-angle + span/2, modulus: 2 * .pi)
        return Int(floor(normalized / span)) % n
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        #if canImport(UIKit)
        guard displayLink == nil else { return }
        lastTimestamp = nil
        let link = CADisplayLink(target: self, selector: #selector(onDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        #else
        // Fallback for macOS - use Timer
        animationTimer?.invalidate()
        lastTimestamp = CACurrentMediaTime()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = CACurrentMediaTime()
                if let last = self.lastTimestamp {
                    self.step(dt: CGFloat(now - last))
                }
                self.lastTimestamp = now
            }
        }
        #endif
    }
    
    private func stopAnimation() {
        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #else
        animationTimer?.invalidate()
        animationTimer = nil
        #endif
        lastTimestamp = nil
    }
    
    #if canImport(UIKit)
    @objc private func onDisplayLink(_ link: CADisplayLink) {
        let t = link.timestamp
        defer { lastTimestamp = t }
        guard let last = lastTimestamp else { return } // wait one frame
        step(dt: CGFloat(t - last))
    }
    #endif
    
    // MARK: - Physics step
    
    private func step(dt: CGFloat) {
        guard isSpinning else { return }
        
        let prevAngle = angle
        angle += angularVelocity * dt
        
        // Air drag (exponential)
        let drag = exp(-airDrag * dt)
        angularVelocity *= drag
        
        // Per-notch peg interaction when crossing boundaries
        applyPegImpulseIfCrossed(from: prevAngle, to: angle)
        
        // Low-speed termination and snap
        if abs(angularVelocity) < stopSpeedThreshold {
            // If nearly aligned to a boundary center, snap & finish
            if nearCenter(angle) {
                isSpinning = false
                angularVelocity = 0
                stopAnimation()
                snapToNearestCenter()
                
                // Call completion with winning segment
                if let callback = onComplete {
                    let winningSegment = segments[highlightedIndex]
                    callback(winningSegment)
                    onComplete = nil
                }
            }
        }
    }
    
    private func applyPegImpulseIfCrossed(from old: CGFloat, to new: CGFloat) {
        let n = max(segments.count, 1)
        let span = 2 * .pi / CGFloat(n)
        
        // Determine if we've crossed at least one boundary (fast frames only cross 1)
        let oldIdx = Int(floor(Self.wrap(old, modulus: 2 * .pi) / span))
        let newIdx = Int(floor(Self.wrap(new, modulus: 2 * .pi) / span))
        guard oldIdx != newIdx else { return }
        
        // Haptic + deflection
        let v = abs(angularVelocity)
        #if canImport(UIKit)
        let intensity = CGFloat(min(max(v / (8 * .pi), 0.15), 1.0))
        haptic.impactOccurred(intensity: intensity)
        #endif
        pegDeflect(forVelocity: v)
        
        // Damping depends on speed
        if v > 1.5 {               // still moving fast
            angularVelocity *= tickDampingFast
        } else {                   // near end
            angularVelocity *= tickDampingSlow
        }
    }
    
    private func pegDeflect(forVelocity v: CGFloat) {
        // Bend peg proportionally, spring back
        let maxDeflect: CGFloat = 16 * .pi / 180 // 16°
        let minDeflect: CGFloat = 7  * .pi / 180 // 7°
        let target = min(max(minDeflect + (v * 0.025), minDeflect), maxDeflect)
        withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
            tickerDeflection = target
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.68)) {
                    self?.tickerDeflection = 0
                }
            }
        }
    }
    
    private func nearCenter(_ angle: CGFloat) -> Bool {
        let n = max(segments.count, 1)
        let span = 2 * .pi / CGFloat(n)
        // Center positions are multiples of span (since our sector 0 is centered at 0)
        let r = Self.wrap(-angle, modulus: 2 * .pi)
        let delta = abs(r.remainder(dividingBy: span))
        // Within ~3° of a center
        return min(delta, span - delta) < (3.0 * .pi / 180)
    }
    
    private func snapToNearestCenter() {
        let n = max(segments.count, 1)
        let span = 2 * .pi / CGFloat(n)
        let k = round((-angle) / span)
        let target = -k * span
        withAnimation(.spring(response: snapSpring.response, dampingFraction: snapSpring.damping)) {
            angle = target
        }
    }
    
    // MARK: - Utils
    
    static func wrap(_ x: CGFloat, modulus m: CGFloat) -> CGFloat {
        let r = x.truncatingRemainder(dividingBy: m)
        return r >= 0 ? r : r + m
    }
    
    public static let defaultSegments: [WheelSegment] = [
        .init(title: "50 Gems", subtitle: "Common prize", icon: "💎", shortLabel: "50", 
              color: .blue, reward: .init(type: .gems, amount: 50)),
        .init(title: "2 Hammers", subtitle: "Remove tiles", icon: "🔨", shortLabel: "2x", 
              color: .orange, reward: .init(type: .hammers, amount: 2)),
        .init(title: "100 Gems", subtitle: "Nice win!", icon: "💎", shortLabel: "100", 
              color: .green, reward: .init(type: .gems, amount: 100)),
        .init(title: "1 Magnet", subtitle: "Attract tiles", icon: "🧲", shortLabel: "1x", 
              color: .purple, reward: .init(type: .magnets, amount: 1)),
        .init(title: "Extra Spin", subtitle: "Spin again!", icon: "🎰", shortLabel: "SPIN", 
              color: .pink, reward: .init(type: .spin, amount: 1)),
        .init(title: "25 Gems", subtitle: "Small prize", icon: "💎", shortLabel: "25", 
              color: .teal, reward: .init(type: .gems, amount: 25)),
        .init(title: "3 Hammers", subtitle: "Jackpot!", icon: "🔨", shortLabel: "3x", 
              color: .red, reward: .init(type: .hammers, amount: 3)),
        .init(title: "75 Gems", subtitle: "Good win", icon: "💎", shortLabel: "75", 
              color: .yellow, reward: .init(type: .gems, amount: 75))
    ]
}

// MARK: - Environment Injection

// Since WheelEngine is MainActor-isolated, we use optional type for environment key
private struct WheelEngineKey: EnvironmentKey {
    static let defaultValue: WheelEngine? = nil
}

public extension EnvironmentValues {
    @MainActor
    var wheelEngine: WheelEngine {
        get { 
            self[WheelEngineKey.self] ?? WheelEngine()
        }
        set { 
            self[WheelEngineKey.self] = newValue
        }
    }
}

// MARK: - HomeState extension to get shared instance

public extension HomeState {
    @MainActor
    static func shared() async throws -> HomeState? {
        // This is a placeholder - in a real app, you'd get the shared instance
        // from your app's dependency injection or state management system
        return nil
    }
}