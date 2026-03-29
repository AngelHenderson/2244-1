import SwiftUI

/// The reason a player was banned. Each case maps to a specific violation
/// detected by the backend's anti-cheat and integrity systems.
public enum BanReason: String, CaseIterable, Sendable {
    case cheating = "cheating or memory editing"
    case fakeCurrency = "fake currency/gem generation"
    case impossibleScore = "impossible scores or impossible progression"
    case speedHack = "speed hacks or timer manipulation"
    case botMacro = "use of bots, macros, or auto-play"
    case exploitAbuse = "exploiting bugs repeatedly for unfair gain"
    case paymentAbuse = "refund or payment abuse"
    case accountViolation = "account selling, sharing, or ban evasion"
}

/// Duration of a ban.
public enum BanDuration: Sendable {
    case temporary(days: Int)
    case permanent

    public var displayText: String {
        switch self {
        case .temporary(let days):
            if days == 1 { return "1 day" }
            if days < 7 { return "\(days) days" }
            if days == 7 { return "1 week" }
            if days == 14 { return "2 weeks" }
            if days == 21 { return "3 weeks" }
            if days == 30 { return "1 month" }
            if days == 60 { return "2 months" }
            if days == 180 { return "6 months" }
            if days == 365 { return "1 year" }
            if days == 730 { return "2 years" }
            if days == 1095 { return "3 years" }
            if days == 1460 { return "4 years" }
            if days == 1825 { return "5 years" }
            return "\(days) days"
        case .permanent:
            return "permanently"
        }
    }
}

/// Builds the ban alert message string for use in a standard `.alert()`.
public enum BanAlert {
    /// Generates the subtitle message for a ban alert.
    public static func message(reason: BanReason, duration: BanDuration) -> String {
        let disabledNote = "Milestone progression, spinwheel, daily rewards, challenge mode, custom challenges, and shop are all disabled until you are unbanned."
        switch duration {
        case .temporary:
            return "You are banned due to \(reason.rawValue). Your account has been suspended for \(duration.displayText). \(disabledNote)"
        case .permanent:
            return "You are banned due to \(reason.rawValue). Your account has been permanently banned. \(disabledNote)"
        }
    }
}

// MARK: - View Modifier

/// A view modifier that attaches a ban alert to any view.
/// Usage: `.banAlert(isPresented: $showBan, reason: .cheating, duration: .temporary(days: 7))`
public struct BanAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let reason: BanReason
    let duration: BanDuration

    public func body(content: Content) -> some View {
        content
            .alert("Banned", isPresented: $isPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(BanAlert.message(reason: reason, duration: duration))
            }
    }
}

public extension View {
    /// Presents a system ban alert with the given reason and duration.
    func banAlert(isPresented: Binding<Bool>, reason: BanReason, duration: BanDuration) -> some View {
        modifier(BanAlertModifier(isPresented: isPresented, reason: reason, duration: duration))
    }
}

#Preview("Ban Alert - Temporary") {
    Color.clear
        .banAlert(
            isPresented: .constant(true),
            reason: .cheating,
            duration: .temporary(days: 7)
        )
}

#Preview("Ban Alert - Permanent") {
    Color.clear
        .banAlert(
            isPresented: .constant(true),
            reason: .accountViolation,
            duration: .permanent
        )
}
