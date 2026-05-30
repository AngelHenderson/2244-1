import SwiftUI

/// Shows a chronological feed of player events: bans, reports, game overs, joins, etc.
struct PlayerHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let entries: [LeaderboardEntry]
    let filterId: String
    
    @State private var events: [HistoryEvent] = []

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
        .onAppear {
            if events.isEmpty {
                events = generateEvents()
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

    private func generateEvents() -> [HistoryEvent] {
        let day = MockLeaderboardData.daysSinceReference
        let eventNow = Date()
        HistoryEvent._nextId = 0  // Reset counter for fresh generation
        var result: [HistoryEvent] = []

        // Generate events for the past 30 days
        for daysAgo in 0..<30 {
            let dailyStartIndex = result.count
            let eventDay = day - daysAgo

            // Helper to make a player name + country for a given seed
            func makePlayer(seed: Int) -> (name: String, country: String, countryName: String, highestTile: String?) {
                if entries.isEmpty {
                    // Fallback
                    let countries = ["US", "GB", "DE", "FR"]
                    let cIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 1, index: eventDay) * Double(countries.count))
                    let country = countries[min(cIdx, countries.count - 1)]
                    let nIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 2, index: eventDay) * 200.0)
                    let name = MockLeaderboardData.nameForPlayer(
                        index: nIdx,
                        names: MockLeaderboardData.hallOfFameNames,
                        countrySeed: seed,
                        day: eventDay
                    )
                    return (name, country, Self.countryDisplayName(for: country), nil)
                } else {
                    // Use entries exactly to ensure they correspond to current rank filter!
                    let index = Int(MockLeaderboardData.seededRandom(seed: seed, index: eventDay) * Double(entries.count))
                    let entry = entries[min(index, entries.count - 1)]
                    let cCode = entry.countryCode ?? "US"
                    return (entry.name, cCode, Self.countryDisplayName(for: cCode), entry.highestTile)
                }
            }

            // === Guaranteed events: 2+ of each type per day ===
            // Bans are NOT generated directly — they emerge from report/false-report post-processing

            // 1) Reported — 3 reports on ONE player → triggers "banned due to three reports"
            //    Then 2 more reports on different players for variety
            let victimSeed = eventDay * 700 + 100
            let victim = makePlayer(seed: victimSeed)
            for i in 0..<3 {
                let reporterSeed = victimSeed + 50 + i * 17
                let reporter = makePlayer(seed: reporterSeed)
                result.append(HistoryEvent(
                    type: .reported,
                    message: "\(victim.name) from \(victim.countryName) leaderboard got reported by \(reporter.name) from \(reporter.countryName).",
                    daysAgo: daysAgo,
                    seed: victimSeed + i
                ))
            }
            // 2 extra reports on different players
            for i in 0..<2 {
                let seed = eventDay * 700 + 130 + i * 11
                let p = makePlayer(seed: seed)
                let rp = makePlayer(seed: seed + 50)
                result.append(HistoryEvent(
                    type: .reported,
                    message: "\(p.name) from \(p.countryName) leaderboard got reported by \(rp.name) from \(rp.countryName).",
                    daysAgo: daysAgo,
                    seed: seed
                ))
            }

            // 2) False reports — ONE player makes false reports that reach 5+ abuse pts
            //    5 pattern variants rotated by day:
            //    A: 1 overtake (+2) + 4 regular (+4) = 6 pts
            //    B: 2 overtakes (+4) + 1 regular (+1) = 5 pts
            //    C: 3 overtakes (+6) = 6 pts (only overtakes)
            //    D: 5 regulars (+5) = 5 pts (only regulars)
            //    E: overtake-regular-overtake (+2,+1,+2) = 5 pts (interleaved)
            //    Then 2 more false reports from different players for variety
            let abuserSeed = eventDay * 700 + 200
            let abuser = makePlayer(seed: abuserSeed)
            
            // Each entry is true = overtake (+2), false = regular (+1)
            let patterns: [[Bool]] = [
                [true, false, false, false, false],       // A: 1 overtake + 4 regular
                [true, false, false, false],              // B: 1 overtake + 3 regular
                [true, true, false],                      // C: 2 overtakes + 1 regular
                [true, true, true],                       // D: only overtakes
                [false, false, false, false, false],      // E: only regulars
                [true, false, true],                      // F: overtake, regular, overtake
            ]
            let patternIdx = Int(MockLeaderboardData.seededRandom(seed: abuserSeed + 99, index: eventDay) * Double(patterns.count))
            let pattern = patterns[min(patternIdx, patterns.count - 1)]
            
            for (i, isOvertake) in pattern.enumerated() {
                if isOvertake {
                    result.append(HistoryEvent(
                        type: .falseReport,
                        playerName: abuser.name,
                        reporterName: "overtake",
                        message: "\(abuser.name) made a false report: \"He is ahead of me in the leaderboard!\" (+2 abuse points)",
                        daysAgo: daysAgo,
                        seed: abuserSeed + i
                    ))
                } else {
                    result.append(HistoryEvent(
                        type: .falseReport,
                        playerName: abuser.name,
                        message: "\(abuser.name) made a false report. (+1 abuse point)",
                        daysAgo: daysAgo,
                        seed: abuserSeed + i
                    ))
                }
            }
            // 2 extra false reports from different players (mix of +1 and +2)
            for i in 0..<2 {
                let seed = eventDay * 700 + 230 + i * 11
                let p = makePlayer(seed: seed)
                let isOvertake = MockLeaderboardData.seededRandom(seed: seed + 42, index: eventDay) < 0.5
                
                if isOvertake {
                    result.append(HistoryEvent(
                        type: .falseReport,
                        playerName: p.name,
                        reporterName: "overtake",
                        message: "\(p.name) made a false report: \"He is ahead of me in the leaderboard!\" (+2 abuse points)",
                        daysAgo: daysAgo,
                        seed: seed
                    ))
                } else {
                    result.append(HistoryEvent(
                        type: .falseReport,
                        playerName: p.name,
                        message: "\(p.name) made a false report. (+1 abuse point)",
                        daysAgo: daysAgo,
                        seed: seed
                    ))
                }
            }

            // 3) Made infinity (x3)
            for i in 0..<3 {
                let seed = eventDay * 700 + 300 + i * 11
                let p = makePlayer(seed: seed)
                let madeInfinityEvent = HistoryEvent(
                    type: .madeInfinity,
                    message: "\(p.name) made infinity!",
                    daysAgo: daysAgo,
                    seed: seed
                )
                result.append(madeInfinityEvent)
            }

            // 4) Game over / out of moves (x3)
            for i in 0..<3 {
                let seed = eventDay * 700 + 400 + i * 11
                let p = makePlayer(seed: seed)
                let reportedTile: String
                if let tile = p.highestTile {
                    reportedTile = tile
                } else {
                    let isInfinity = i == 0
                    if isInfinity {
                        let infinityValues = [
                            2, 5, 8, 12, 19, 27, 34, 45, 62, 85, 110, 145,
                            180, 250, 340, 480, 650, 920, 1300, 1850, 2600, 3500,
                            4800, 6500, 9200, 12500, 18000, 25000, 34000, 48000,
                            65000, 88000, 120000, 160000, 220000, 310000
                        ]
                        let iIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 8, index: eventDay) * Double(infinityValues.count))
                        reportedTile = "\(infinityValues[min(iIdx, infinityValues.count - 1)])∞"
                    } else {
                        let allM = MockLeaderboardData.allMilestones
                        let mIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 9, index: eventDay) * Double(allM.count))
                        reportedTile = allM[min(mIdx, allM.count - 1)]
                    }
                }
                
                result.append(HistoryEvent(
                    type: .gameOver,
                    message: "\(p.name) ran out of moves at \(reportedTile).",
                    daysAgo: daysAgo,
                    seed: seed
                ))
                // ~40% recovery
                if MockLeaderboardData.seededRandom(seed: seed + 12, index: eventDay) < 0.4 {
                    let recoveryDate = result.last!.eventDate.addingTimeInterval(60)
                    result.append(HistoryEvent(
                        type: .moveRecovery,
                        message: "\(p.name) recovered their moves and is back in the game!",
                        daysAgo: daysAgo,
                        seed: seed + 999,
                        overrideDate: recoveryDate
                    ))
                }
            }

            // 5) Deleted (x3)
            for i in 0..<3 {
                let seed = eventDay * 700 + 500 + i * 11
                let p = makePlayer(seed: seed)
                result.append(HistoryEvent(
                    type: .deleted,
                    message: "\(p.name) deleted the game.",
                    daysAgo: daysAgo,
                    seed: seed
                ))
            }

            // 6) Restart (x3)
            for i in 0..<3 {
                let seed = eventDay * 700 + 600 + i * 11
                let p = makePlayer(seed: seed)
                result.append(HistoryEvent(
                    type: .restart,
                    message: "\(p.name) chose to restart their progress.",
                    daysAgo: daysAgo,
                    seed: seed
                ))
            }

            // 7) Direct bans for serious offenses (1-2 per day)
            //    These are NOT from reports — they're system-detected violations
            let directBanReasons = [
                "cheating",
                "account sharing",
                "using third-party tools",
                "score manipulation",
                "multi-accounting",
                "exploiting a game bug",
                "using an unauthorized modified client",
                "suspicious activity"
            ]
            let directBanDurations = [
                "two weeks", "one month", "two months",
                "six months", "one year", "two years", "five years",
                "permanently"
            ]
            let directBanCount = 3 + Int(MockLeaderboardData.seededRandom(seed: eventDay * 700 + 650, index: eventDay) * 3.0)
            for i in 0..<directBanCount {
                let seed = eventDay * 700 + 660 + i * 13
                let p = makePlayer(seed: seed)
                let banMessage: String
                
                // ~25% of system bans are for impossible infinity counts
                if MockLeaderboardData.seededRandom(seed: seed + 42, index: eventDay) < 0.25 {
                    let cheatCount = 50 + Int(MockLeaderboardData.seededRandom(seed: seed + 43, index: eventDay) * 400_000.0)
                    let timeframes = ["5 minutes", "10 minutes", "15 minutes", "30 minutes", "1 hour", "2 hours", "4 hours", "12 hours", "1 day", "2 days"]
                    let tIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 45, index: eventDay) * Double(timeframes.count))
                    let timeframe = timeframes[min(tIdx, timeframes.count - 1)]

                    let durIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 46, index: eventDay) * Double(directBanDurations.count))
                    let duration = cheatCount >= 20000
                        ? "permanently"
                        : directBanDurations[min(durIdx, directBanDurations.count - 1)]
                    
                    let flavorType = Int(MockLeaderboardData.seededRandom(seed: seed + 44, index: eventDay) * 2.0)
                    let reason = flavorType == 0 
                        ? "reaching \(cheatCount)∞ counts in \(timeframe)"
                        : "reaching \(cheatCount) Infinities in \(timeframe)"
                        
                    if duration == "permanently" {
                        banMessage = "\(p.name) got permanently banned due to \(reason)."
                    } else {
                        banMessage = "\(p.name) got banned for \(duration) due to \(reason)."
                    }
                } else {
                    let reasonIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 3, index: eventDay) * Double(directBanReasons.count))
                    let reason = directBanReasons[min(reasonIdx, directBanReasons.count - 1)]
                    let durIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 5, index: eventDay) * Double(directBanDurations.count))
                    let duration = directBanDurations[min(durIdx, directBanDurations.count - 1)]
                    
                    if duration == "permanently" {
                        banMessage = "\(p.name) got permanently banned due to \(reason)."
                    } else {
                        banMessage = "\(p.name) got banned for \(duration) due to \(reason)."
                    }
                }
                
                result.append(HistoryEvent(
                    type: .banned,
                    playerName: p.name,
                    message: banMessage,
                    daysAgo: daysAgo,
                    seed: seed
                ))
            }

            // === Extra random events (2-3 per day for variety) ===
            // (recovery events after game-overs also add to the daily total)
            let extraCount = 2 + Int(MockLeaderboardData.seededRandom(seed: 55555, index: eventDay) * 2.0)
            for eventIndex in 0..<extraCount {
                let seed = eventDay * 100 + eventIndex
                let random = MockLeaderboardData.seededRandom(seed: seed, index: eventDay)
                let p = makePlayer(seed: seed)

                let event: HistoryEvent

                if random < 0.30 {
                    // Extra reported event (bans come from post-processing)
                    let rp = makePlayer(seed: seed + 50)
                    event = HistoryEvent(
                        type: .reported,
                        message: "\(p.name) from \(p.countryName) leaderboard got reported by \(rp.name) from \(rp.countryName).",
                        daysAgo: daysAgo,
                        seed: seed
                    )
                } else if random < 0.47 {
                    let rp = makePlayer(seed: seed + 50)
                    event = HistoryEvent(
                        type: .reported,
                        message: "\(p.name) from \(p.countryName) leaderboard got reported by \(rp.name) from \(rp.countryName).",
                        daysAgo: daysAgo,
                        seed: seed
                    )
                } else if random < 0.60 {
                    let isOvertake = MockLeaderboardData.seededRandom(seed: seed + 13, index: eventDay) < 0.4
                    if isOvertake {
                        event = HistoryEvent(
                            type: .falseReport,
                            playerName: p.name,
                            reporterName: "overtake",
                            message: "\(p.name) made a false report: \"He is ahead of me in the leaderboard!\" (+2 abuse points)",
                            daysAgo: daysAgo,
                            seed: seed
                        )
                    } else {
                        event = HistoryEvent(
                            type: .falseReport,
                            playerName: p.name,
                            message: "\(p.name) made a false report. (+1 abuse point)",
                            daysAgo: daysAgo,
                            seed: seed
                        )
                    }
                } else if random < 0.65 {
                    event = HistoryEvent(
                        type: .madeInfinity,
                        message: "\(p.name) made infinity!",
                        daysAgo: daysAgo,
                        seed: seed
                    )
                } else if random < 0.85 {
                    let reportedTile: String
                    if let tile = p.highestTile {
                        reportedTile = tile
                    } else {
                        let isInfinityPlayer = MockLeaderboardData.seededRandom(seed: seed + 7, index: eventDay) < 0.4
                        if isInfinityPlayer {
                            let infinityValues = [
                                2, 5, 8, 12, 19, 27, 34, 45, 62, 85, 110, 145,
                                180, 250, 340, 480, 650, 920, 1300, 1850, 2600, 3500,
                                4800, 6500, 9200, 12500, 18000, 25000, 34000, 48000,
                                65000, 88000, 120000, 160000, 220000, 310000
                            ]
                            let iIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 8, index: eventDay) * Double(infinityValues.count))
                            reportedTile = "\(infinityValues[min(iIdx, infinityValues.count - 1)])∞"
                        } else {
                            let allM = MockLeaderboardData.allMilestones
                            let milestoneIdx = Int(MockLeaderboardData.seededRandom(seed: seed + 9, index: eventDay) * Double(allM.count))
                            reportedTile = allM[min(milestoneIdx, allM.count - 1)]
                        }
                    }
                    event = HistoryEvent(
                        type: .gameOver,
                        message: "\(p.name) ran out of moves at \(reportedTile).",
                        daysAgo: daysAgo,
                        seed: seed
                    )

                    if MockLeaderboardData.seededRandom(seed: seed + 12, index: eventDay) < 0.4 {
                        let gameOverEvent = event
                        let recoveryDate = gameOverEvent.eventDate.addingTimeInterval(60)
                        let recovery = HistoryEvent(
                            type: .moveRecovery,
                            message: "\(p.name) recovered their moves and is back in the game!",
                            daysAgo: daysAgo,
                            seed: seed + 999,
                            overrideDate: recoveryDate
                        )
                        result.append(recovery)
                    }
                } else if random < 0.92 {
                    event = HistoryEvent(
                        type: .deleted,
                        message: "\(p.name) deleted the game.",
                        daysAgo: daysAgo,
                        seed: seed
                    )
                } else {
                    event = HistoryEvent(
                        type: .restart,
                        message: "\(p.name) chose to restart their progress.",
                        daysAgo: daysAgo,
                        seed: seed
                    )
                }

                result.append(event)
            }

            // Generate join events separately using actual joining rates
            
            // Pick 2-3 countries that had joins visible in the feed today
            let visibleCountryCount = 2 + Int(MockLeaderboardData.seededRandom(seed: 77777, index: eventDay) * 2.0)
            let fallbackCountries = ["US", "BR", "GB", "DE", "JP", "IN", "FR", "MX", "AU", "CA",
                                     "KR", "IT", "ES", "NL", "SE", "NO", "CH", "AT", "NZ", "IE",
                                     "VN", "KZ", "CW", "AZ", "TJ", "KE", "ZA", "FJ", "PH", "TH"]
            
            for countryIdx in 0..<visibleCountryCount {
                let cSeed = eventDay * 50 + countryIdx
                let cIndex = Int(MockLeaderboardData.seededRandom(seed: cSeed, index: eventDay) * Double(fallbackCountries.count))
                
                let country: String
                if filterId == "global" || filterId == "hof" || filterId.isEmpty {
                    country = fallbackCountries[min(cIndex, fallbackCountries.count - 1)]
                } else {
                    country = filterId
                }
                
                let countryName = Self.countryDisplayName(for: country)

                // Use actual joining rate to determine how many joins to show for this country
                let joiningRate = MockLeaderboardData.newPlayersJoining(on: eventDay, countrySeed: cSeed)
                // Show 1-3 of the day's joins in the feed (not all 10-40, just a sample)
                let visibleJoins = max(1, min(3, Int(joiningRate / 10.0)))

                for joinIdx in 0..<visibleJoins {
                    let joinSeed = eventDay * 300 + countryIdx * 10 + joinIdx
                    
                    // We can reuse the `makePlayer` closure for consistency where we map matching names,
                    // but since they 'just joined', using random mock names here is technically fine too.
                    // Let's use `makePlayer` to just get a generic player, but we ignore the `makePlayer`'s
                    // country tracking and just use `countryName`.
                    let randomPlayer = makePlayer(seed: joinSeed)
                    
                    let messageStr = (countryName == "Hall of Fame") 
                        ? "\(randomPlayer.name) reached infinity and joined the Hall of Fame."
                        : "\(randomPlayer.name) joined the \(countryName) leaderboard."
                        
                    result.append(HistoryEvent(
                        type: .joined,
                        message: messageStr,
                        daysAgo: daysAgo,
                        seed: joinSeed
                    ))
                }
            }
            
            // --- DISTRIBUTE EVENTS FOR THIS DAY EVENLY ---
            let dailyCount = result.count - dailyStartIndex
            if dailyCount > 0 {
                // Separate recovery events from the rest — they must stay paired with their game over
                var normalIndices: [Int] = []
                var recoveryIndices: [Int] = []
                for idx in dailyStartIndex..<result.count {
                    if result[idx].type == .moveRecovery {
                        recoveryIndices.append(idx)
                    } else {
                        normalIndices.append(idx)
                    }
                }
                
                // Deterministic shuffle for non-recovery events
                normalIndices.sort { result[$0].id < result[$1].id }
                
                for (i, targetIdx) in normalIndices.enumerated() {
                    let hour = i % 24
                    // Deterministic minute (use bitwise AND to avoid abs(Int.min) overflow crash)
                    let minute = ((result[targetIdx].message.hashValue &* 11) & 0x7FFFFFFF) % 60
                    
                    let calendar = Calendar.current
                    var components = calendar.dateComponents([.year, .month, .day], from: result[targetIdx].eventDate)
                    components.hour = hour
                    components.minute = minute
                    result[targetIdx].eventDate = calendar.date(from: components) ?? result[targetIdx].eventDate
                }
                
                // Re-attach each recovery event to 1 minute after its paired game over
                // The recovery is always appended right after its game over, so walk backward to find it
                for recoveryIdx in recoveryIndices {
                    let recoveryPlayerName = result[recoveryIdx].message.components(separatedBy: " recovered").first ?? ""
                    // Search backward from recoveryIdx for the matching gameOver
                    for searchIdx in stride(from: recoveryIdx - 1, through: dailyStartIndex, by: -1) {
                        if result[searchIdx].type == .gameOver,
                           result[searchIdx].message.hasPrefix(recoveryPlayerName) {
                            result[recoveryIdx].eventDate = result[searchIdx].eventDate.addingTimeInterval(60)
                            break
                        }
                    }
                }
            }
        }
        // --- INJECT REAL BANS ---
        let allPlayers = MockLeaderboardData.allSearchablePlayers()
        let entryIds = Set(entries.map { $0.id })
        let relevantPlayers = allPlayers.filter { entryIds.contains($0.id) }
        
        var realBanNames = Set<String>()
        
        for p in relevantPlayers {
            let components = p.id.components(separatedBy: "_")
            guard components.count == 2, let i = Int(components[1]) else { continue }
            let countryCode = components[0].uppercased()
            let configSeed = MockLeaderboardData.countrySeed(for: countryCode)
            
            let banSeed = (i &+ 1) &* 31 &+ configSeed &* 17
            let timeHash = abs(banSeed &* 123456789) % 100
            
            if p.isBanned {
                let durationStr: String
                let totalSeconds: Int
                if timeHash < 20 {
                    totalSeconds = -1
                    durationStr = "permanently"
                } else {
                    let days = 1 + (timeHash % 30)
                    totalSeconds = days * 86400
                    if days == 1 { durationStr = "1 day" }
                    else if days < 7 { durationStr = "\(days) days" }
                    else if days == 7 { durationStr = "1 week" }
                    else if days == 14 { durationStr = "2 weeks" }
                    else if days == 21 { durationStr = "3 weeks" }
                    else if days == 30 { durationStr = "1 month" }
                    else { durationStr = "\(days) days" }
                }
                
                let banDate: Date
                if totalSeconds == -1 {
                    let daysAgo = timeHash % 30
                    banDate = Date().addingTimeInterval(-Double(daysAgo * 86400))
                } else if let endDate = p.banEndDate {
                    banDate = endDate.addingTimeInterval(-Double(totalSeconds))
                } else {
                    continue
                }
                
                if banDate >= Date().addingTimeInterval(-30 * 86400) && banDate <= Date() {
                    let directBanReasons = [
                        "cheating", "account sharing", "using third-party tools",
                        "score manipulation", "multi-accounting", "exploiting a game bug",
                        "using an unauthorized modified client", "suspicious activity"
                    ]
                    let reason = directBanReasons[timeHash % directBanReasons.count]
                    
                    let banMessage: String
                    if totalSeconds == -1 {
                        banMessage = "\(p.name) got permanently banned due to \(reason)."
                    } else {
                        banMessage = "\(p.name) got banned for \(durationStr) due to \(reason)."
                    }
                    
                    realBanNames.insert(p.name)
                    
                    result.append(HistoryEvent(
                        type: .banned,
                        playerName: p.name,
                        message: banMessage,
                        daysAgo: 0,
                        seed: banSeed,
                        overrideDate: banDate
                    ))
                }
            }
        }
        
        // Remove fake bans for players that have real bans to avoid duplicates
        result.removeAll { event in
            event.type == .banned && event.playerName != nil && realBanNames.contains(event.playerName!) && event.seed != 0
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
            "1 day", "1 week", "2 weeks", "3 weeks",
            "1 month", "2 months", "6 months",
            "1 year", "2 years", "3 years", "4 years", "5 years"
        ]

        // Track starting ladder index per player (based on their first offense severity)
        var banStartIndex: [String: Int] = [:]

        var reportCounts: [String: Int] = [:]  // tracks how many times each player was reported
        let reportsUntilReview = 3  // number of reports before action is taken

        var pendingUnbans: [(name: String, unbanDate: Date)] = []
        
        func intervalForDuration(_ duration: String) -> TimeInterval? {
            if duration == "1 day" { return 86400 }
            if duration == "1 week" { return 86400 * 7 }
            if duration == "2 weeks" { return 86400 * 14 }
            if duration == "3 weeks" { return 86400 * 21 }
            if duration == "1 month" { return 86400 * 30 }
            if duration == "2 months" { return 86400 * 60 }
            if duration == "6 months" { return 86400 * 180 }
            if duration == "1 year" { return 86400 * 365 }
            if duration == "2 years" { return 86400 * 365 * 2 }
            if duration == "3 years" { return 86400 * 365 * 3 }
            if duration == "4 years" { return 86400 * 365 * 4 }
            if duration == "5 years" { return nil }
            if duration.hasSuffix(" days"), let daysStr = duration.components(separatedBy: " ").first, let days = Int(daysStr) {
                return Double(days * 86400)
            }
            return nil
        }

        for event in result.reversed() {
            // Check if any pending unbans should happen before this event
            pendingUnbans.removeAll { pending in
                if pending.unbanDate <= event.eventDate {
                    processed.append(HistoryEvent(
                        type: .unbanned,
                        message: "\(pending.name) was unbanned after serving their penalty.",
                        daysAgo: 0, seed: 0, overrideDate: pending.unbanDate
                    ))
                    playerBanned[pending.name] = false
                    return true
                }
                return false
            }
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
                    
                    let ghostSeed = name.hashValue & 0x7FFFFFFF
                    // Ensure deterministic ghost name based on the original name
                    let nIdx = (ghostSeed &* 17) % MockLeaderboardData.hallOfFameNames.count
                    let ghostName = MockLeaderboardData.hallOfFameNames[nIdx]
                    
                    // Retroactively swap all occurrences of `name` with `ghostName` in processed
                    for idx in 0..<processed.count {
                        if processed[idx].message.contains(name) {
                            processed[idx] = HistoryEvent(
                                type: processed[idx].type,
                                playerName: processed[idx].playerName == name ? ghostName : processed[idx].playerName,
                                reporterName: processed[idx].reporterName == name ? ghostName : processed[idx].reporterName,
                                message: processed[idx].message.replacingOccurrences(of: name, with: ghostName),
                                daysAgo: 0, seed: 0, overrideDate: processed[idx].eventDate
                            )
                        }
                    }
                    
                    let targetName = ghostName

                    // Seed the starting ladder index from player name for variety
                    if banStartIndex[name] == nil {
                        let nameHash = targetName.hashValue & 0x7FFFFFFF
                        banStartIndex[name] = nameHash % 2  // Cap to one day – one week for report-based bans
                    }
                    let startIdx = banStartIndex[name] ?? 0
                    let duration = escalationLadder[min(startIdx + banNumber, 1)]  // Cap to one week max for report-based bans
                    if let interval = intervalForDuration(duration) {
                        pendingUnbans.append((targetName, event.eventDate.addingTimeInterval(interval)))
                    }
                    processed.append(HistoryEvent(
                        type: .banned,
                        message: "\(targetName) got banned for \(duration) due to accumulating 5 abuse points from false reports.",
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

                // Skip further reports after player is already banned
                if playerBanned[reportedName] == true { continue }

                let count = (reportCounts[reportedName] ?? 0) + 1
                reportCounts[reportedName] = count

                if count >= reportsUntilReview {
                    // Player reached report threshold — ban them
                    reportCounts[reportedName] = 0  // Reset so future reports after unban start fresh
                    playerBanned[reportedName] = true
                    let banNumber = banCounts[reportedName] ?? 0
                    banCounts[reportedName] = banNumber + 1
                    
                    let ghostSeed = reportedName.hashValue & 0x7FFFFFFF
                    // Ensure deterministic ghost name based on the original name
                    let nIdx = (ghostSeed &* 17) % MockLeaderboardData.hallOfFameNames.count
                    let ghostName = MockLeaderboardData.hallOfFameNames[nIdx]
                    
                    // Retroactively swap all occurrences of `reportedName` with `ghostName` in processed
                    for idx in 0..<processed.count {
                        if processed[idx].message.contains(reportedName) {
                            processed[idx] = HistoryEvent(
                                type: processed[idx].type,
                                playerName: processed[idx].playerName == reportedName ? ghostName : processed[idx].playerName,
                                reporterName: processed[idx].reporterName == reportedName ? ghostName : processed[idx].reporterName,
                                message: processed[idx].message.replacingOccurrences(of: reportedName, with: ghostName),
                                daysAgo: 0, seed: 0, overrideDate: processed[idx].eventDate
                            )
                        }
                    }
                    
                    let targetName = ghostName

                    // Seed the starting ladder index from player name for variety
                    if banStartIndex[reportedName] == nil {
                        let nameHash = targetName.hashValue & 0x7FFFFFFF
                        banStartIndex[reportedName] = nameHash % 2  // Cap to one day – one week for report-based bans
                    }
                    let startIdx = banStartIndex[reportedName] ?? 0
                    let duration = escalationLadder[min(startIdx + banNumber, 1)]  // Cap to one week max for report-based bans

                    if let interval = intervalForDuration(duration) {
                        pendingUnbans.append((targetName, event.eventDate.addingTimeInterval(interval)))
                    }
                    let banWord = banNumber > 0 ? "re-banned" : "banned"
                    processed.append(HistoryEvent(
                        type: .banned,
                        message: "\(targetName) got \(banWord) for \(duration) due to three reports.",
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
                // For direct system bans, pass through the original message on first offense
                // Only escalate if this player has been banned before in this cycle
                let banNumber = banCounts[name] ?? 0
                banCounts[name] = banNumber + 1

                if banNumber == 0 {
                    // First ban — use the original duration and reason as-is
                    // Extract duration for unban scheduling
                    if let forRange = event.message.range(of: "banned for "),
                       let dueRange = event.message.range(of: " due to") {
                        let originalDuration = String(event.message[forRange.upperBound..<dueRange.lowerBound])
                        if let interval = intervalForDuration(originalDuration) {
                            pendingUnbans.append((name, event.eventDate.addingTimeInterval(interval)))
                        }
                    }
                    // Pass through unchanged
                    processed.append(HistoryEvent(
                        type: .banned,
                        message: event.message,
                        daysAgo: 0,
                        seed: 0,
                        overrideDate: event.eventDate
                    ))
                } else {
                    if event.message.contains("permanently") {
                        // Permanent system bans should never be downgraded by the escalation ladder
                        processed.append(HistoryEvent(
                            type: .banned,
                            message: event.message,
                            daysAgo: 0,
                            seed: 0,
                            overrideDate: event.eventDate
                        ))
                        continue
                    }

                    // Repeat offender — escalate using ladder
                    // Determine the system's intended duration for this specific offense
                    var intendedIndex = 4 // Fallback to "two weeks"
                    if let forRange = event.message.range(of: "banned for "),
                       let dueRange = event.message.range(of: " due to") {
                        let initialDuration = String(event.message[forRange.upperBound..<dueRange.lowerBound])
                        intendedIndex = escalationLadder.firstIndex(of: initialDuration) ?? 4
                    }
                    
                    let baseIdx = banStartIndex[name] ?? 0
                    
                    // The new ladder index is the max of:
                    // 1) Their previous ladder tier + 1 (escalated)
                    // 2) The severity of the new offense itself
                    // 3) At least 4 ("two weeks") because this is a system ban
                    let ladderIndex = max(baseIdx + banNumber, intendedIndex, 4)
                    
                    // Update their base index so future bans escalate properly from here
                    banStartIndex[name] = max(0, ladderIndex - banNumber)
                    
                    let escalatedDuration = escalationLadder[min(ladderIndex, escalationLadder.count - 1)]

                    // Extract the reason from the original message
                    let reason: String
                    if let range = event.message.range(of: "due to ") {
                        reason = String(event.message[range.upperBound...]).replacingOccurrences(of: ".", with: "")
                    } else {
                        reason = "repeated offenses"
                    }

                    if let interval = intervalForDuration(escalatedDuration) {
                        pendingUnbans.append((name, event.eventDate.addingTimeInterval(interval)))
                    }
                    let banWord = banNumber > 0 ? "re-banned" : "banned"
                    processed.append(HistoryEvent(
                        type: .banned,
                        message: "\(name) got \(banWord) for \(escalatedDuration) due to \(reason).",
                        daysAgo: 0,
                        seed: 0,
                        overrideDate: event.eventDate
                    ))
                }
            } else {
                processed.append(event)
            }
        }

        // Add any pending unbans that mature before now (deduplicate by name, keep latest)
        let now = Date()
        var seenUnbanNames = Set<String>()
        // Process from main loop already emitted some unbans — collect those names
        for ev in processed where ev.type == .unbanned {
            // Extract the name from "X was unbanned after serving their penalty."
            if let range = ev.message.range(of: " was unbanned") {
                seenUnbanNames.insert(String(ev.message[ev.message.startIndex..<range.lowerBound]))
            }
        }
        for pending in pendingUnbans {
            if pending.unbanDate <= now, !seenUnbanNames.contains(pending.name) {
                seenUnbanNames.insert(pending.name)
                processed.append(HistoryEvent(
                    type: .unbanned,
                    message: "\(pending.name) was unbanned after serving their penalty.",
                    daysAgo: 0, seed: 0, overrideDate: pending.unbanDate
                ))
            }
        }

        // Filter out future events that haven't 'happened' yet today
        let filtered = processed.filter { $0.eventDate <= eventNow }
        
        // Reverse back to newest-first, re-sorting to guarantee correct order
        return filtered.sorted { $0.eventDate > $1.eventDate }
    }

    private static func countryDisplayName(for code: String) -> String {
        switch code {
        case "US": return "US"
        case "BR": return "Brazil"
        case "GB": return "UK"
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
        case banned, reported, chanceTaken, falseReport, madeInfinity, gameOver, moveRecovery, joined, deleted, restart, unbanned
    }

    let id: String
    let type: EventType
    let message: String
    var eventDate: Date
    let playerName: String?
    let reporterName: String?
    let seed: Int

    nonisolated(unsafe) static var _nextId = 0
    private static func nextUniqueId() -> Int {
        _nextId += 1
        return _nextId
    }

    init(type: EventType, playerName: String? = nil, reporterName: String? = nil, message: String, daysAgo: Int, seed: Int, overrideDate: Date? = nil) {
        self.id = "\(seed)_\(daysAgo)_\(type)_\(Self.nextUniqueId())"
        self.type = type
        self.message = message
        self.playerName = playerName
        self.reporterName = reporterName
        self.seed = seed

        // If an override date is provided (post-processing), use it directly
        if let override = overrideDate {
            self.eventDate = override
            return
        }

        // Build an actual date from daysAgo + seeded time
        let calendar = Calendar.current
        let now = Date()

        // Generate deterministic hour (0-23) and minute (0-59) from seed
        let hour = (((seed &* 13) &+ 7) & 0x7FFFFFFF) % 24
        let minute = (((seed &* 31) &+ 11) & 0x7FFFFFFF) % 60

        // Always use the deterministic time. 
        // We will filter out future events during post-processing.
        let pastDay = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: pastDay)
        components.hour = hour
        components.minute = minute
        self.eventDate = calendar.date(from: components) ?? pastDay
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
        case .unbanned: return "lock.open.fill"
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
        case .unbanned: return .green
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

#if DEBUG
#Preview("Player History") {
    PlayerHistoryView(
        entries: ScreenPreviewFixtures.leaderboardEntries,
        filterId: "global"
    )
}
#endif
