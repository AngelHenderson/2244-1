import SwiftUI

/// Shows a chronological feed of player events: bans, reports, game overs, joins, etc.
struct PlayerHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    private let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.14)

    var body: some View {
        ZStack {
            darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.avenirNext(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                }
                .overlay {
                    Text("PLAYER HISTORY")
                        .font(.avenirNext(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(events) { event in
                            eventRow(event)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Event Row

    @ViewBuilder
    private func eventRow(_ event: HistoryEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(event.iconBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: event.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.message)
                    .font(.avenirNext(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(event.timeAgo)
                    .font(.avenirNext(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Event Generation

    private var events: [HistoryEvent] {
        Self.generateEvents()
    }

    private static func generateEvents() -> [HistoryEvent] {
        let day = MockLeaderboardData.daysSinceReference
        var result: [HistoryEvent] = []

        // Generate events for the past 30 days
        for daysAgo in 0..<30 {
            let eventDay = day - daysAgo

            // Use seeded random for deterministic events per day
            let eventCount = 3 + Int(MockLeaderboardData.seededRandom(seed: 55555, index: eventDay) * 5.0) // 3-7 events per day

            for eventIndex in 0..<eventCount {
                let seed = eventDay * 100 + eventIndex
                let random = MockLeaderboardData.seededRandom(seed: seed, index: eventDay)

                // Pick a country for this event
                let countries = ["US", "BR", "GB", "DE", "JP", "IN", "FR", "MX", "AU", "CA",
                                 "KR", "IT", "ES", "NL", "SE", "NO", "CH", "AT", "NZ", "IE",
                                 "VN", "KZ", "CW", "AZ", "TJ", "KE", "ZA", "FJ", "PH", "TH"]
                let countryIndex = Int(MockLeaderboardData.seededRandom(seed: seed + 1, index: eventDay) * Double(countries.count))
                let country = countries[min(countryIndex, countries.count - 1)]
                let countryName = Self.countryDisplayName(for: country)

                // Generate player name
                let nameIndex = Int(MockLeaderboardData.seededRandom(seed: seed + 2, index: eventDay) * 200.0)
                let playerName = MockLeaderboardData.nameForPlayer(
                    index: nameIndex,
                    names: MockLeaderboardData.hallOfFameNames,
                    countrySeed: seed,
                    day: eventDay
                )

                let event: HistoryEvent

                if random < 0.28 {
                    // Banned event (28%)
                    let reasons = [
                        "cheating", "using third-party tools", "exploiting game bugs",
                        "inappropriate behavior", "account sharing", "score manipulation",
                        "false reports"
                    ]
                    let reasonIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 3, index: eventDay) * Double(reasons.count))
                    let reason = reasons[min(reasonIdx, reasons.count - 1)]

                    // Pick a ban duration from the escalation ladder
                    let durations = [
                        "one day", "two days", "three days", "one week", "two weeks",
                        "three weeks", "one month", "two months", "six months",
                        "one year", "two years", "five years"
                    ]
                    // Use eventIndex * prime + daysAgo to spread across all durations
                    let durationIdx = abs(eventIndex * 37 + daysAgo * 13 + seed) % (durations.count + 1)

                    let message: String
                    if durationIdx >= durations.count {
                        message = "\(playerName) got permanently banned due to \(reason)."
                    } else {
                        let duration = durations[min(durationIdx, durations.count - 1)]
                        message = "\(playerName) got banned for \(duration) due to \(reason)."
                    }

                    event = HistoryEvent(
                        type: .banned,
                        message: message,
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.47 {
                    // Reported event (19%)
                    let reporterNameIndex = Int(MockLeaderboardData.seededRandom(seed: seed + 4, index: eventDay) * 200.0)
                    let reporterName = MockLeaderboardData.nameForPlayer(
                        index: reporterNameIndex,
                        names: MockLeaderboardData.hallOfFameNames,
                        countrySeed: seed + 100,
                        day: eventDay
                    )

                    let reporterCountryIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 5, index: eventDay) * Double(countries.count))
                    let reporterCountry = countries[min(reporterCountryIdx, countries.count - 1)]
                    let reporterCountryName = Self.countryDisplayName(for: reporterCountry)

                    event = HistoryEvent(
                        type: .reported,
                        message: "\(playerName) from \(countryName) leaderboard got reported by \(reporterName) from \(reporterCountryName).",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.54 {
                    // Chance taken away (7%)
                    let reporterNameIndex = Int(MockLeaderboardData.seededRandom(seed: seed + 10, index: eventDay) * 200.0)
                    let reporterName = MockLeaderboardData.nameForPlayer(
                        index: reporterNameIndex,
                        names: MockLeaderboardData.hallOfFameNames,
                        countrySeed: seed + 200,
                        day: eventDay
                    )
                    let chancesLeft = MockLeaderboardData.seededRandom(seed: seed + 11, index: eventDay) < 0.5 ? 1 : 2

                    event = HistoryEvent(
                        type: .chanceTaken,
                        message: "\(playerName) got a chance taken away due to a report from \(reporterName). (\(chancesLeft) chance\(chancesLeft == 1 ? "" : "s") remaining)",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.60 {
                    // False report (6%)
                    event = HistoryEvent(
                        type: .falseReport,
                        message: "\(playerName) made a false report.",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.65 {
                    // Made infinity (7%)
                    event = HistoryEvent(
                        type: .madeInfinity,
                        message: "\(playerName) made infinity!",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.80 {
                    // Out of moves (10%) — split between regular and infinity players
                    let isInfinityPlayer = MockLeaderboardData.seededRandom(seed: seed + 7, index: eventDay) < 0.4
                    if isInfinityPlayer {
                        let infinityCount = 1 + Int(MockLeaderboardData.seededRandom(seed: seed + 8, index: eventDay) * 150.0)
                        event = HistoryEvent(
                            type: .gameOver,
                            message: "\(playerName) ran out of moves at \(infinityCount)∞.",
                            daysAgo: daysAgo,
                            seed: seed
                        )
                    } else {
                        // Regular player with a milestone
                        let milestoneValues = [
                            "16M", "8M", "4M", "2M", "1M", "524K", "262K", "131K", "65K", "32K",
                            "16K", "8192", "4096", "2048", "1024", "512", "256", "128",
                            "199as", "47br", "3bw", "106by", "28ax", "84al", "803p", "604d",
                            "590c", "576b", "549B", "268M", "134M", "67M", "33M",
                            "726ao", "994y", "7u", "6s", "3r", "1q", "79f", "19e"
                        ]
                        let milestoneIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 9, index: eventDay) * Double(milestoneValues.count))
                        let milestone = milestoneValues[min(milestoneIdx, milestoneValues.count - 1)]
                        event = HistoryEvent(
                            type: .gameOver,
                            message: "\(playerName) ran out of moves at \(milestone).",
                            daysAgo: daysAgo,
                            seed: seed
                        )
                    }

                } else if random < 0.85 {
                    // Move recovery (5%)
                    event = HistoryEvent(
                        type: .moveRecovery,
                        message: "\(playerName) recovered their moves and is back in the game!",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.92 {
                    // Joined (12%)
                    event = HistoryEvent(
                        type: .joined,
                        message: "\(playerName) joined the \(countryName) leaderboard.",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.96 {
                    // Deleted (4%)
                    event = HistoryEvent(
                        type: .deleted,
                        message: "\(playerName) deleted the game.",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else {
                    // Restart (4%)
                    event = HistoryEvent(
                        type: .restart,
                        message: "\(playerName) chose to restart their progress.",
                        daysAgo: daysAgo,
                        seed: seed
                    )
                }

                result.append(event)
            }
        }
        // Sort by date, newest first
        result.sort { $0.eventDate > $1.eventDate }

        return result
    }

    private static func countryDisplayName(for code: String) -> String {
        switch code {
        case "US": return "United States"
        case "BR": return "Brazil"
        case "GB": return "United Kingdom"
        case "DE": return "Germany"
        case "JP": return "Japan"
        case "IN": return "India"
        case "FR": return "France"
        case "MX": return "Mexico"
        case "AU": return "Australia"
        case "CA": return "Canada"
        case "KR": return "South Korea"
        case "IT": return "Italy"
        case "ES": return "Spain"
        case "NL": return "Netherlands"
        case "SE": return "Sweden"
        case "NO": return "Norway"
        case "CH": return "Switzerland"
        case "AT": return "Austria"
        case "NZ": return "New Zealand"
        case "IE": return "Ireland"
        case "VN": return "Vietnam"
        case "KZ": return "Kazakhstan"
        case "CW": return "Curaçao"
        case "AZ": return "Azerbaijan"
        case "TJ": return "Tajikistan"
        case "KE": return "Kenya"
        case "ZA": return "South Africa"
        case "FJ": return "Fiji"
        case "PH": return "Philippines"
        case "TH": return "Thailand"
        default: return code
        }
    }
}

// MARK: - Model

struct HistoryEvent: Identifiable {
    enum EventType {
        case banned, reported, chanceTaken, falseReport, madeInfinity, gameOver, moveRecovery, joined, deleted, restart
    }

    let id: String
    let type: EventType
    let message: String
    let eventDate: Date

    init(type: EventType, message: String, daysAgo: Int, seed: Int) {
        self.id = "\(seed)_\(daysAgo)_\(type)"
        self.type = type
        self.message = message

        // Build an actual date from daysAgo + seeded time
        let calendar = Calendar.current
        let now = Date()

        // Generate deterministic hour (0-23) and minute (0-59) from seed
        let hour = abs(seed * 13 + 7) % 24
        let minute = abs(seed * 31 + 11) % 60

        if daysAgo == 0 {
            // Today: cap to before the current time
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            let cappedHour = min(hour, currentHour)
            let cappedMinute = cappedHour == currentHour ? min(minute, max(0, currentMinute - 1)) : minute

            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = cappedHour
            components.minute = cappedMinute
            self.eventDate = calendar.date(from: components) ?? now
        } else {
            // Past days: any time is fine
            let pastDay = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            var components = calendar.dateComponents([.year, .month, .day], from: pastDay)
            components.hour = hour
            components.minute = minute
            self.eventDate = calendar.date(from: components) ?? pastDay
        }
    }

    var iconName: String {
        switch type {
        case .banned: return "nosign"
        case .reported: return "exclamationmark.triangle.fill"
        case .chanceTaken: return "minus.circle.fill"
        case .falseReport: return "hand.thumbsdown.fill"
        case .madeInfinity: return "infinity"
        case .gameOver: return "xmark.circle.fill"
        case .moveRecovery: return "heart.fill"
        case .joined: return "person.badge.plus"
        case .deleted: return "trash.fill"
        case .restart: return "arrow.counterclockwise"
        }
    }

    var iconBackground: Color {
        switch type {
        case .banned: return .red
        case .reported: return .orange
        case .chanceTaken: return Color(red: 0.9, green: 0.4, blue: 0.2)
        case .falseReport: return .yellow
        case .madeInfinity: return .purple
        case .gameOver: return Color(red: 0.6, green: 0.3, blue: 0.1)
        case .moveRecovery: return .teal
        case .joined: return .green
        case .deleted: return .gray
        case .restart: return .blue
        }
    }

    var timeAgo: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let time = timeFormatter.string(from: eventDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let date = dateFormatter.string(from: eventDate)

        let calendar = Calendar.current
        if calendar.isDateInToday(eventDate) {
            return "\(time) today · \(date)"
        } else if calendar.isDateInYesterday(eventDate) {
            return "\(time) yesterday · \(date)"
        } else {
            return "\(time) at \(date)"
        }
    }
}
