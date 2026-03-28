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
    public let iconAssetName: String?
    public let shortLabel: String
    public let color: Color
    public let reward: WheelReward
    public let weight: Int  // Weight for probability (default 1, Gift Box uses 2)

    public init(
        title: String,
        subtitle: String,
        icon: String,
        iconAssetName: String? = nil,
        shortLabel: String,
        color: Color,
        reward: WheelReward,
        weight: Int = 1
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconAssetName = iconAssetName
        self.shortLabel = shortLabel
        self.color = color
        self.reward = reward
        self.weight = weight
    }
}

public struct WheelReward: Hashable, Sendable {
    public enum RewardType: Hashable, Sendable {
        case gems
        case hammers
        case magnets
        case spin
        case swap
        case multiplier(SpinWheelState.MultiplierTier)
        case giftBox
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

    // Tick sound callback - called when crossing each divider
    public var onTick: (() -> Void)?

    // Pin physics state
    private var pinVelocity: CGFloat = 0         // angular velocity of pin
    private var pinSpringK: CGFloat = 850        // spring stiffness
    private var pinDamping: CGFloat = 18         // damping coefficient
    private var pinMass: CGFloat = 1.0           // effective mass
    private var lastDividerIndex: Int = -1       // track which divider we last hit

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

        // Reset pin physics
        pinVelocity = 0
        tickerDeflection = 0
        lastDividerIndex = -1

        // 5.5–8.5 rotations/sec initial => lively, but not crazy
        // Always spin clockwise (positive direction)
        let rps = Double.random(in: 5.5...8.5)
        angularVelocity = CGFloat(rps * 2.0 * .pi)
        isSpinning = true
        startAnimation()
    }

    // MARK: - Weighted Segment Geometry

    /// Total weight of all segments (used for calculating proportional sizes)
    public var totalWeight: Int {
        segments.reduce(0) { $0 + $1.weight }
    }

    /// Returns the angular span (in radians) for a segment at the given index
    public func segmentSpan(at index: Int) -> CGFloat {
        let weight = segments[index].weight
        return CGFloat(weight) / CGFloat(totalWeight) * 2 * .pi
    }

    /// Returns the starting angle (in radians) for a segment at the given index
    public func segmentStartAngle(at index: Int) -> CGFloat {
        var startAngle: CGFloat = 0
        for i in 0..<index {
            startAngle += segmentSpan(at: i)
        }
        return startAngle
    }

    /// Returns the center angle (in radians) for a segment at the given index
    public func segmentCenterAngle(at index: Int) -> CGFloat {
        segmentStartAngle(at: index) + segmentSpan(at: index) / 2
    }
    
    public func stop() {
        isSpinning = false
        angularVelocity = 0
        stopAnimation()
        // Snap to nearest center
        snapToNearestCenter()
    }
    
    // Computed: which segment is currently under the top peg (index)
    // Uses weighted segment sizes for accurate hit detection
    public var highlightedIndex: Int {
        let normalized = Self.wrap(-angle, modulus: 2 * .pi)
        var cumulative: CGFloat = 0
        for i in 0..<segments.count {
            cumulative += segmentSpan(at: i)
            if normalized < cumulative {
                return i
            }
        }
        return 0
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

        // Check for divider crossing and apply impulse to wheel
        checkDividerCrossing(from: prevAngle, to: angle)

        // Simulate pin physics (spring-mass-damper system)
        simulatePinPhysics(dt: dt)

        // Low-speed termination - stop wherever the wheel lands
        if abs(angularVelocity) < stopSpeedThreshold {
            isSpinning = false
            angularVelocity = 0
            pinVelocity = 0
            tickerDeflection = 0
            stopAnimation()

            // Call completion with the segment the pin landed on
            if let callback = onComplete {
                let winningSegment = segments[highlightedIndex]
                callback(winningSegment)
                onComplete = nil
            }
        }
    }

    private func simulatePinPhysics(dt: CGFloat) {
        // Use -angle to match highlightedIndex - this is the position under the pin
        let normalizedAngle = Self.wrap(-angle, modulus: 2 * .pi)

        // Find which segment we're in and position within it
        var cumulative: CGFloat = 0
        var currentSpan: CGFloat = segmentSpan(at: 0)
        var segmentStart: CGFloat = 0

        for i in 0..<segments.count {
            let span = segmentSpan(at: i)
            if normalizedAngle < cumulative + span {
                currentSpan = span
                segmentStart = cumulative
                break
            }
            cumulative += span
        }

        let positionInSlice = normalizedAngle - segmentStart
        let distanceToPrevEdge = positionInSlice

        // Contact zone where pin touches divider (proportional to segment size)
        let contactZone: CGFloat = currentSpan * 0.20
        let maxDeflect: CGFloat = 24 * .pi / 180 // 24° max

        // Calculate target deflection based on contact
        var targetDeflection: CGFloat = 0

        // Check if we're near an edge and deflect accordingly
        if distanceToPrevEdge < contactZone {
            // Just passed an edge - pin moves with the divider (right when spinning clockwise)
            let penetration = (contactZone - distanceToPrevEdge) / contactZone
            targetDeflection = -penetration * maxDeflect

            let speedFactor = min(abs(angularVelocity) / 8.0, 2.0)
            targetDeflection *= (1.0 + speedFactor * 0.4)
        }

        // Spring-mass-damper physics: F = -kx - cv
        let displacement = tickerDeflection - targetDeflection
        let springForce = -pinSpringK * displacement
        let dampingForce = -pinDamping * pinVelocity

        // Calculate acceleration (F = ma)
        let acceleration = (springForce + dampingForce) / pinMass

        // Integrate velocity and position (semi-implicit Euler)
        pinVelocity += acceleration * dt
        tickerDeflection += pinVelocity * dt

        // Clamp deflection to reasonable range
        let clampedMax: CGFloat = 28 * .pi / 180
        tickerDeflection = max(-clampedMax, min(clampedMax, tickerDeflection))

        // Apply velocity damping for stability
        pinVelocity *= 0.985
    }
    
    private func checkDividerCrossing(from old: CGFloat, to new: CGFloat) {
        // Use -angle to find which segment is under the pin (matches highlightedIndex)
        let oldIdx = segmentIndex(for: -old)
        let newIdx = segmentIndex(for: -new)

        // Check if we crossed a divider
        guard oldIdx != newIdx else { return }

        // We crossed a divider - apply haptic feedback and tick sound
        let v = abs(angularVelocity)
#if canImport(UIKit)
        let intensity = CGFloat(min(max(v / (8 * .pi), 0.15), 1.0))
        haptic.impactOccurred(intensity: intensity)
#endif
        // Play tick sound
        onTick?()

        // Give the pin an impulse when hitting divider (adds to natural spring response)
        let impulseStrength = min(v * 0.08, 2.5)
        pinVelocity += impulseStrength

        // Apply wheel damping - divider slows down the wheel slightly
        if v > 1.5 {
            angularVelocity *= tickDampingFast
        } else {
            angularVelocity *= tickDampingSlow
        }

        lastDividerIndex = newIdx
    }

    /// Returns the segment index for a given angle (using weighted geometry)
    private func segmentIndex(for angle: CGFloat) -> Int {
        let normalized = Self.wrap(angle, modulus: 2 * .pi)
        var cumulative: CGFloat = 0
        for i in 0..<segments.count {
            cumulative += segmentSpan(at: i)
            if normalized < cumulative {
                return i
            }
        }
        return 0
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
        pinVelocity = 0
        withAnimation(.spring(response: snapSpring.response, dampingFraction: snapSpring.damping)) {
            angle = target
            tickerDeflection = 0
        }
    }

    private func snapToSegment(index: Int) {
        let n = max(segments.count, 1)
        let span = 2 * .pi / CGFloat(n)
        // Calculate target angle so segment at index is under the peg (at top)
        let targetAngle = -CGFloat(index) * span
        pinVelocity = 0
        withAnimation(.spring(response: snapSpring.response, dampingFraction: snapSpring.damping)) {
            angle = targetAngle
            tickerDeflection = 0
        }
    }
    
    // MARK: - Utils
    
    static func wrap(_ x: CGFloat, modulus m: CGFloat) -> CGFloat {
        let r = x.truncatingRemainder(dividingBy: m)
        return r >= 0 ? r : r + m
    }
    
    public static let defaultSegments: [WheelSegment] = [
        // 15 segments with weighted probability:
        // Gift Box has weight 2 (12.5% = 2/16), others have weight 1 (6.25% = 1/16 each)
        // Total weight = 2 + 14 = 16, giving Gift Box 12.5% and others 6.25%
        .init(title: "Gift Box", subtitle: "Mystery prize", icon: "🎁", iconAssetName: "GiftBoxIcon", shortLabel: "?",
              color: Color(red: 0.97, green: 0.73, blue: 0.20), reward: .init(type: .giftBox, amount: 1), weight: 2),
        .init(title: "4X Boost", subtitle: "12h multiplier", icon: "⚡️", shortLabel: "4X",
              color: Color(red: 0.14, green: 0.41, blue: 0.96), reward: .init(type: .multiplier(.fourX), amount: 1)),
        .init(title: "2 Swaps", subtitle: "Strategic swaps", icon: "🔁", iconAssetName: "SwapIcon", shortLabel: "2x",
              color: Color(red: 90.0/255.0, green: 58.0/255.0, blue: 1.0), reward: .init(type: .swap, amount: 2)),
        .init(title: "1 Hammer", subtitle: "Smash a tile", icon: "🔨", iconAssetName: "HammerIcon", shortLabel: "1x",
              color: Color.orange, reward: .init(type: .hammers, amount: 1)),
        .init(title: "2 Free Spins", subtitle: "Spin again twice!", icon: "🎡", iconAssetName: "FreeSpinIcon", shortLabel: "+2",
              color: Color(red: 0.10, green: 0.60, blue: 0.36), reward: .init(type: .spin, amount: 2)),
        .init(title: "1 MegaMerge", subtitle: "Pull tiles in", icon: "🧲", iconAssetName: "MegaMergeIcon", shortLabel: "1x",
              color: Color.purple, reward: .init(type: .magnets, amount: 1)),
        .init(title: "200 Gems", subtitle: "Big payout", icon: "💎", iconAssetName: "GemBagIcon", shortLabel: "200",
              color: Color(red: 0.04, green: 0.54, blue: 0.82), reward: .init(type: .gems, amount: 200)),
        .init(title: "2 Hammers", subtitle: "Double smash", icon: "🛠️", iconAssetName: "HammerIcon", shortLabel: "2x",
              color: Color(red: 0.85, green: 0.42, blue: 0.24), reward: .init(type: .hammers, amount: 2)),
        .init(title: "3X Boost", subtitle: "18h multiplier", icon: "⚡️", shortLabel: "3X",
              color: Color(red: 0.20, green: 0.64, blue: 0.93), reward: .init(type: .multiplier(.threeX), amount: 1)),
        .init(title: "300 Gems", subtitle: "Jackpot", icon: "💎", iconAssetName: "GemBagIcon", shortLabel: "300",
              color: Color(red: 0.00, green: 0.38, blue: 0.69), reward: .init(type: .gems, amount: 300)),
        .init(title: "1 Free Spin", subtitle: "Spin again", icon: "🎡", iconAssetName: "FreeSpinIcon", shortLabel: "+1",
              color: Color(red: 0.16, green: 0.78, blue: 0.46), reward: .init(type: .spin, amount: 1)),
        .init(title: "2 MegaMerges", subtitle: "Double pull", icon: "🧲", iconAssetName: "MegaMergeIcon", shortLabel: "2x",
              color: Color(red: 0.64, green: 0.29, blue: 0.99), reward: .init(type: .magnets, amount: 2)),
        .init(title: "2X Boost", subtitle: "24h multiplier", icon: "⚡️", shortLabel: "2X",
              color: Color(red: 0.36, green: 0.80, blue: 0.98), reward: .init(type: .multiplier(.twoX), amount: 1)),
        .init(title: "100 Gems", subtitle: "Shimmering win", icon: "💎", iconAssetName: "gem", shortLabel: "100",
              color: Color(red: 0.08, green: 0.71, blue: 0.94), reward: .init(type: .gems, amount: 100)),
        .init(title: "1 Swap", subtitle: "Swap tiles", icon: "🔁", iconAssetName: "SwapIcon", shortLabel: "1x",
              color: Color(red: 126.0/255.0, green: 91.0/255.0, blue: 1.0), reward: .init(type: .swap, amount: 1))
    ]
}

// MARK: - Environment Injection (file scope)

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

// MARK: - HomeState extension (file scope)

public extension HomeState {
    @MainActor
    static func shared() async throws -> HomeState? {
        // This is a placeholder - in a real app, you'd get the shared instance
        // from your app's dependency injection or state management system
        return nil
    }
}
