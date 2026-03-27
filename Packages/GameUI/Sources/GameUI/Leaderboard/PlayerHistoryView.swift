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

    // Cache events so timestamps don't shift on re-render
    nonisolated(unsafe) private static var cachedDay: Int = -1
    nonisolated(unsafe) private static var cachedEvents: [HistoryEvent] = []

    private var events: [HistoryEvent] {
        let today = MockLeaderboardData.daysSinceReference
        if Self.cachedDay != today || Self.cachedEvents.isEmpty {
            Self.cachedEvents = Self.generateEvents()
            Self.cachedDay = today
        }
        return Self.cachedEvents
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
                    // Each reason maps to a severity tier with appropriate duration ranges
                    // Minor: 1 day – 1 week  |  Medium: 2 weeks – 2 months  |  Severe: 6 months – permanent
                    let reasonsWithDurations: [(reason: String, durations: [String])] = [
                        ("inappropriate behavior", ["one day", "two days", "three days", "one week"]),
                        ("false reports", ["one day", "two days", "three days", "one week"]),
                        ("account sharing", ["two weeks", "three weeks", "one month", "two months"]),
                        ("score manipulation", ["two weeks", "three weeks", "one month", "two months"]),
                        ("cheating", ["six months", "one year", "two years", "five years"]),
                        ("using third-party tools", ["six months", "one year", "two years", "five years"]),
                        ("exploiting game bugs", ["one year", "two years", "five years"]),
                    ]
                    let reasonIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 3, index: eventDay) * Double(reasonsWithDurations.count))
                    let entry = reasonsWithDurations[min(reasonIdx, reasonsWithDurations.count - 1)]
                    let reason = entry.reason

                    // Starting duration index — post-processing will escalate from here
                    let durationIdx = abs(eventIndex * 37 + daysAgo * 13 + seed) % entry.durations.count
                    let duration = entry.durations[min(durationIdx, entry.durations.count - 1)]

                    event = HistoryEvent(
                        type: .banned,
                        playerName: playerName,
                        message: "\(playerName) got banned for \(duration) due to \(reason).",
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

                } else if random < 0.60 {
                    // False report (13%) — split into regular and leaderboard overtake
                    // Leaderboard overtakes = 2 abuse points, others = 1 abuse point
                    // At 5+ abuse points → banned
                    let isOvertake = MockLeaderboardData.seededRandom(seed: seed + 13, index: eventDay) < 0.4
                    if isOvertake {
                        event = HistoryEvent(
                            type: .falseReport,
                            playerName: playerName,
                            reporterName: "overtake",  // marker for 2 abuse points
                            message: "\(playerName) made a false report due to reporting someone ahead of him in the leaderboard. (+2 abuse points)",
                            daysAgo: daysAgo,
                            seed: seed
                        )
                    } else {
                        event = HistoryEvent(
                            type: .falseReport,
                            playerName: playerName,
                            message: "\(playerName) made a false report. (+1 abuse point)",
                            daysAgo: daysAgo,
                            seed: seed
                        )
                    }

                } else if random < 0.65 {
                    // Made infinity (7%)
                    event = HistoryEvent(
                        type: .madeInfinity,
                        message: "\(playerName) made infinity!",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else if random < 0.85 {
                    // Out of moves (15%) — split between regular and infinity players
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

                    // ~40% of game over players recover their moves (same player, same minute)
                    if MockLeaderboardData.seededRandom(seed: seed + 12, index: eventDay) < 0.4 {
                        // Use seed + 999 for unique ID; override date to be 1 minute after game over
                        let gameOverEvent = event
                        let recoveryDate = gameOverEvent.eventDate.addingTimeInterval(60)
                        let recovery = HistoryEvent(
                            type: .moveRecovery,
                            message: "\(playerName) recovered their moves and is back in the game!",
                            daysAgo: daysAgo,
                            seed: seed + 999,
                            overrideDate: recoveryDate
                        )
                        result.append(recovery)
                    }

                } else if random < 0.92 {
                    // Deleted (8%)
                    event = HistoryEvent(
                        type: .deleted,
                        message: "\(playerName) deleted the game.",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                } else {
                    // Restart (8%)
                    event = HistoryEvent(
                        type: .restart,
                        message: "\(playerName) chose to restart their progress.",
                        daysAgo: daysAgo,
                        seed: seed
                    )
                }

                result.append(event)
            }

            // Generate join events separately using actual joining rates
            let countries = ["US", "BR", "GB", "DE", "JP", "IN", "FR", "MX", "AU", "CA",
                             "KR", "IT", "ES", "NL", "SE", "NO", "CH", "AT", "NZ", "IE",
                             "VN", "KZ", "CW", "AZ", "TJ", "KE", "ZA", "FJ", "PH", "TH"]

            // Pick 2-3 countries that had joins visible in the feed today
            let visibleCountryCount = 2 + Int(MockLeaderboardData.seededRandom(seed: 77777, index: eventDay) * 2.0)
            for countryIdx in 0..<visibleCountryCount {
                let cSeed = eventDay * 50 + countryIdx
                let cIndex = Int(MockLeaderboardData.seededRandom(seed: cSeed, index: eventDay) * Double(countries.count))
                let country = countries[min(cIndex, countries.count - 1)]
                let countryName = Self.countryDisplayName(for: country)

                // Use actual joining rate to determine how many joins to show for this country
                let joiningRate = MockLeaderboardData.countryNewPlayersJoining(on: eventDay, countrySeed: cSeed)
                // Show 1-3 of the day's joins in the feed (not all 10-40, just a sample)
                let visibleJoins = max(1, min(3, Int(joiningRate / 10.0)))

                for joinIdx in 0..<visibleJoins {
                    let joinSeed = eventDay * 300 + countryIdx * 10 + joinIdx
                    let nameIdx = Int(MockLeaderboardData.seededRandom(seed: joinSeed + 2, index: eventDay) * 200.0)
                    let joinPlayerName = MockLeaderboardData.nameForPlayer(
                        index: nameIdx,
                        names: MockLeaderboardData.hallOfFameNames,
                        countrySeed: joinSeed,
                        day: eventDay
                    )
                    result.append(HistoryEvent(
                        type: .joined,
                        message: "\(joinPlayerName) joined the \(countryName) leaderboard.",
                        daysAgo: daysAgo,
                        seed: joinSeed
                    ))
                }
            }
        }
        // Sort by date, newest first
        result.sort { $0.eventDate > $1.eventDate }

        // Post-process: track abuse points from false reports AND escalate ban durations
        // Leaderboard overtake = 2 abuse points, other false reports = 1 point
        // At 5+ abuse points → banned (with escalating duration for repeat offenders)
        var abusePoints: [String: Int] = [:]  // tracks abuse points per player
        var banCounts: [String: Int] = [:]  // tracks how many bans per player for escalation
        var playerBanned: [String: Bool] = [:]  // whether player already got banned this cycle
        var processed: [HistoryEvent] = []

        // Escalation ladder — each subsequent ban moves up from their starting tier
        let escalationLadder = [
            "one day", "two days", "three days", "one week",
            "two weeks", "one month", "two months",
            "six months", "one year", "two years", "five years"
        ]

        // Track starting ladder index per player (based on their first offense severity)
        var banStartIndex: [String: Int] = [:]

        var reportCounts: [String: Int] = [:]  // tracks how many times each player was reported
        let reportsUntilReview = 3  // number of reports before action is taken

        for event in result.reversed() {
            if event.type == .falseReport, let name = event.playerName {
                // Skip further false reports after player is already banned
                if playerBanned[name] == true { continue }

                let isOvertake = event.reporterName == "overtake"
                let points = isOvertake ? 2 : 1
                let currentPoints = (abusePoints[name] ?? 0) + points
                abusePoints[name] = currentPoints

                if currentPoints >= 5 {
                    // Threshold reached — ban the player
                    let banNumber = banCounts[name] ?? 0
                    banCounts[name] = banNumber + 1
                    playerBanned[name] = true
                    let startIdx = banStartIndex[name] ?? 0
                    let duration = escalationLadder[min(startIdx + banNumber, escalationLadder.count - 1)]
                    processed.append(HistoryEvent(
                        type: .banned,
                        message: "\(name) got banned for \(duration) due to accumulating \(currentPoints) abuse points from false reports.",
                        daysAgo: 0,
                        seed: 0,
                        overrideDate: event.eventDate
                    ))
                } else {
                    // Show the false report with current abuse point total
                    let remaining = 5 - currentPoints
                    var msg = event.message
                    // Append remaining threshold info
                    msg = msg.replacingOccurrences(of: ".", with: "") + " (\(remaining) point\(remaining == 1 ? "" : "s") until ban)"
                    processed.append(HistoryEvent(
                        type: .falseReport,
                        message: msg,
                        daysAgo: 0,
                        seed: 0,
                        overrideDate: event.eventDate
                    ))
                }

            } else if event.type == .reported {
                // Track report count for the reported player
                // Extract the reported player's name (first part of message before " from")
                let reportedName: String
                if let fromRange = event.message.range(of: " from ") {
                    reportedName = String(event.message[event.message.startIndex..<fromRange.lowerBound])
                } else {
                    reportedName = "Unknown"
                }

                let count = (reportCounts[reportedName] ?? 0) + 1
                reportCounts[reportedName] = count

                if count >= reportsUntilReview {
                    // Player reached report threshold — ban them
                    playerBanned[reportedName] = true
                    let banNumber = banCounts[reportedName] ?? 0
                    banCounts[reportedName] = banNumber + 1
                    let startIdx = banStartIndex[reportedName] ?? 0
                    let duration = escalationLadder[min(startIdx + banNumber, escalationLadder.count - 1)]

                    processed.append(HistoryEvent(
                        type: .banned,
                        message: "\(reportedName) got banned for \(duration) due to three reports.",
                        daysAgo: 0,
                        seed: 0,
                        overrideDate: event.eventDate
                    ))
                } else {
                    let remaining = reportsUntilReview - count
                    var msg = event.message.replacingOccurrences(of: ".", with: "")
                    msg += " (\(remaining) more report\(remaining == 1 ? "" : "s") until ban)"

                    processed.append(HistoryEvent(
                        type: .reported,
                        message: msg,
                        daysAgo: 0,
                        seed: 0,
                        overrideDate: event.eventDate
                    ))
                }

            } else if event.type == .banned, let name = event.playerName {
                // Escalate ban duration for repeat offenders
                let banNumber = banCounts[name] ?? 0

                // On first ban, find where their initial duration sits on the ladder
                if banNumber == 0 {
                    if let forRange = event.message.range(of: "banned for "),
                       let dueRange = event.message.range(of: " due to") {
                        let initialDuration = String(event.message[forRange.upperBound..<dueRange.lowerBound])
                        let startIdx = escalationLadder.firstIndex(of: initialDuration) ?? 0
                        banStartIndex[name] = startIdx
                    }
                }

                banCounts[name] = banNumber + 1
                let startIdx = banStartIndex[name] ?? 0
                let escalatedDuration = escalationLadder[min(startIdx + banNumber, escalationLadder.count - 1)]

                // Extract the reason from the original message
                let reason: String
                if let range = event.message.range(of: "due to ") {
                    reason = String(event.message[range.upperBound...]).replacingOccurrences(of: ".", with: "")
                } else {
                    reason = "repeated offenses"
                }

                processed.append(HistoryEvent(
                    type: .banned,
                    message: "\(name) got banned for \(escalatedDuration) due to \(reason).",
                    daysAgo: 0,
                    seed: 0,
                    overrideDate: event.eventDate
                ))
            } else {
                processed.append(event)
            }
        }

        // Reverse back to newest-first
        processed.reverse()

        // Safely filter events to only those generated in the last 30 simulated days
        // Instead of Calendar.current.date(byAdding...) which relies on absolute time,
        // we keep the 30 days generated within this loop, as they are already capped
        // during generation. We just return the processed array.
        return processed
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
    let playerName: String?
    let reporterName: String?

    init(type: EventType, playerName: String? = nil, reporterName: String? = nil, message: String, daysAgo: Int, seed: Int, overrideDate: Date? = nil) {
        self.id = "\(seed)_\(daysAgo)_\(type)_\(message.hashValue)"
        self.type = type
        self.message = message
        self.playerName = playerName
        self.reporterName = reporterName

        // If an override date is provided (post-processing), use it directly
        if let override = overrideDate {
            self.eventDate = override
            return
        }

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
