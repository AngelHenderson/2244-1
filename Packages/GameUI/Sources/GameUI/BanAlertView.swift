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

/// Duration of a ban. Temporary bans show remaining time; permanent bans
/// show a fixed message.
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

/// A full-screen ban alert overlay. Displays the ban reason, duration,
/// and an acknowledgement button. Designed to block all interaction
/// until the player acknowledges the ban.
public struct BanAlertView: View {
    let reason: BanReason
    let duration: BanDuration
    let offenseNumber: Int
    let onDismiss: () -> Void

    private let darkBg = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let dangerRed = Color(red: 0.85, green: 0.15, blue: 0.15)

    public init(
        reason: BanReason,
        duration: BanDuration,
        offenseNumber: Int = 1,
        onDismiss: @escaping () -> Void
    ) {
        self.reason = reason
        self.duration = duration
        self.offenseNumber = offenseNumber
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Ban icon
                ZStack {
                    Circle()
                        .fill(dangerRed.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Circle()
                        .fill(dangerRed.opacity(0.25))
                        .frame(width: 76, height: 76)

                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(dangerRed)
                }
                .padding(.bottom, 24)

                // Title
                Text("Banned")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                // Subtitle - ban reason and duration
                VStack(spacing: 6) {
                    Text("You are banned due to \(reason.rawValue).")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text(durationMessage)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                // Info card
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(icon: "clock.fill", label: "Duration", value: duration.displayText)
                    infoRow(icon: "number", label: "Offense", value: offenseLabel)
                    infoRow(icon: "shield.slash.fill", label: "Reason", value: reason.rawValue.capitalized)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(dangerRed.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // Restriction notice
                Text("While banned, you cannot play, sync progress, access leaderboards, participate in events, or earn rewards.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    Text("I Understand")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(dangerRed)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var durationMessage: String {
        switch duration {
        case .temporary(let days):
            return "Your account has been suspended for \(duration.displayText)."
        case .permanent:
            return "Your account has been permanently banned."
        }
    }

    private var offenseLabel: String {
        switch offenseNumber {
        case 1: return "1st offense"
        case 2: return "2nd offense"
        case 3: return "3rd offense"
        default: return "\(offenseNumber)th offense"
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(dangerRed.opacity(0.8))
                .frame(width: 24)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview("Ban Alert - Temporary") {
    BanAlertView(
        reason: .cheating,
        duration: .temporary(days: 7),
        offenseNumber: 1,
        onDismiss: {}
    )
}

#Preview("Ban Alert - Permanent") {
    BanAlertView(
        reason: .accountViolation,
        duration: .permanent,
        offenseNumber: 15,
        onDismiss: {}
    )
}
