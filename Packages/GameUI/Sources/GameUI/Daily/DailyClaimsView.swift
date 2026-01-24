import SwiftUI
import GameApp
import GameServices

@MainActor
public struct DailyClaimsView: View {
    @Environment(DailyClaimsStore.self) private var store
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @State private var showClaimAnimation = false
    @State private var claimedRewards: AchievementDef.Rewards?
    @State private var claimedBaseRewards: AchievementDef.Rewards?
    @State private var selectedPage = 0
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.indigo.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        availabilitySection
                        
                        claimsPagerSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Daily Rewards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            store.updateAvailability()
            syncSelectedPage()
        }
        .onChange(of: store.currentClaimDay) { _, _ in
            syncSelectedPage()
        }
        .onChange(of: store.dailyClaims.count) { _, _ in
            store.ensureClaimsCovering(pageIndex: selectedPage)
        }
        .onChange(of: selectedPage) { _, newValue in
            store.ensureClaimsCovering(pageIndex: newValue)
        }
        .overlay {
            if showClaimAnimation, let rewards = claimedRewards {
                ClaimAnimationOverlay(rewards: rewards, baseRewards: claimedBaseRewards)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(100)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Streak indicator
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(store.currentStreak > 0 ? .orange : .gray)
                    .symbolEffect(.pulse, isActive: store.currentStreak > 0)
                
                Text("\(store.currentStreak)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Day Streak")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            
            // Current progress
            HStack {
                Label("Day \(store.currentClaimDay) Completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
    }
    
    private var availabilitySection: some View {
        Group {
            if store.canClaimToday {
                claimTodaySection
            } else {
                nextClaimSection
            }
        }
    }
    
    private var claimTodaySection: some View {
        VStack(spacing: 12) {
            if let nextDay = store.getNextClaimableDay(),
               let claim = store.dailyClaims.first(where: { $0.day == nextDay }) {
                let bonusCount = store.pendingStreakBonusCount(afterClaimingDay: nextDay)

                Text("Day \(claim.day) Reward Available!")
                    .font(.headline)

                RewardsDisplay(rewards: claim.rewards)
                    .font(.title3)

                if bonusCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(.orange)
                        Text("+ \(bonusCount) Random Bonus\(bonusCount > 1 ? "es" : "")!")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }

                Text("Claim it from the timeline below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var nextClaimSection: some View {
        VStack(spacing: 12) {
            Text("Next Claim Available In")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if let timeRemaining = store.getTimeUntilNextClaim() {
                TimerView(timeRemaining: timeRemaining)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var claimsPagerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Rewards")
                    .font(.title2.bold())
                Spacer()
                weekNavigator
            }
            
            if chunkedClaims.isEmpty {
                Text("Rewards loading...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                TabView(selection: $selectedPage) {
                    let highlightDay = store.getNextClaimableDay() ?? (store.currentClaimDay + 1)
                    ForEach(Array(chunkedClaims.enumerated()), id: \.offset) { index, claims in
                        // Special full-page layout for Day 365 (Year 1)
                        if index == 52, let day365 = claims.first, day365.day == 365 {
                            YearlyRewardPageView(
                                claim: day365,
                                currentClaimDay: store.currentClaimDay,
                                yearNumber: 1,
                                onClaim: day365.isAvailable ? { claimReward(day365.rewards) } : nil
                            )
                            .tag(index)
                        // Special full-page layout for Day 730 (Year 2)
                        } else if index == 106, let day730 = claims.first, day730.day == 730 {
                            YearlyRewardPageView(
                                claim: day730,
                                currentClaimDay: store.currentClaimDay,
                                yearNumber: 2,
                                onClaim: day730.isAvailable ? { claimReward(day730.rewards) } : nil
                            )
                            .tag(index)
                        } else {
                            WeekGridView(
                                claims: claims,
                                currentClaimDay: store.currentClaimDay,
                                highlightDay: highlightDay,
                                nextDay: store.getNextClaimableDay(),
                                combinedRewardForNext: store.combinedRewardForNextClaim(),
                                onClaim: { claim in claimReward(claim.rewards) }
                            )
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 7 * 86)
            }
        }
    }
    
    private var chunkedClaims: [[DailyClaimsStore.DailyClaim]] {
        // Special handling for yearly rewards:
        // - Pages 0-51: Weeks 1-52 (days 1-364)
        // - Page 52: Day 365 (Year 1)
        // - Page 53: Week 53 (days 366-371, 6 days)
        // - Pages 54-104: Weeks 54-104 (days 372-728)
        // - Page 105: Week 105 first part (day 729 only)
        // - Page 106: Day 730 (Year 2)
        // - Page 107: Rest of Week 105 (days 731-735, 5 days)
        // - Pages 108+: Week 106+ (days 736+)
        var chunks: [[DailyClaimsStore.DailyClaim]] = []
        let claims = store.dailyClaims

        // First 364 days in normal 7-day chunks (weeks 1-52)
        let regularDays = claims.filter { $0.day <= 364 }
        chunks.append(contentsOf: regularDays.chunked(into: 7))

        // Day 365 as its own page (Year 1)
        if let day365 = claims.first(where: { $0.day == 365 }) {
            chunks.append([day365])
        }

        // Week 53: Days 366-371 (6 days only)
        let week53Days = claims.filter { $0.day >= 366 && $0.day <= 371 }
        if !week53Days.isEmpty {
            chunks.append(week53Days)
        }

        // Days 372-728 in 7-day chunks (weeks 54-104)
        let year2RegularDays = claims.filter { $0.day >= 372 && $0.day <= 728 }
        if !year2RegularDays.isEmpty {
            chunks.append(contentsOf: year2RegularDays.chunked(into: 7))
        }

        // Week 105 first part: Day 729 only
        if let day729 = claims.first(where: { $0.day == 729 }) {
            chunks.append([day729])
        }

        // Day 730 as its own page (Year 2)
        if let day730 = claims.first(where: { $0.day == 730 }) {
            chunks.append([day730])
        }

        // Rest of Week 105: Days 731-735 (5 days)
        let week105Rest = claims.filter { $0.day >= 731 && $0.day <= 735 }
        if !week105Rest.isEmpty {
            chunks.append(week105Rest)
        }

        // Days 736+ in 7-day chunks (week 106+)
        let year3Days = claims.filter { $0.day >= 736 }
        if !year3Days.isEmpty {
            chunks.append(contentsOf: year3Days.chunked(into: 7))
        }

        return chunks
    }

    private func pageIndex(for day: Int) -> Int {
        if day <= 364 {
            return (day - 1) / 7
        } else if day == 365 {
            return 52  // Day 365 page
        } else if day <= 371 {
            return 53  // Week 53 (days 366-371)
        } else if day <= 728 {
            // Days 372-728: pages 54-104
            return 54 + (day - 372) / 7
        } else if day == 729 {
            return 105  // Week 105 first part
        } else if day == 730 {
            return 106  // Day 730 page
        } else if day <= 735 {
            return 107  // Rest of Week 105
        } else {
            // Days 736+: page 108 + offset
            return 108 + (day - 736) / 7
        }
    }

    private func syncSelectedPage() {
        let focusDay = store.getNextClaimableDay() ?? max(store.currentClaimDay, 1)
        let targetPage = pageIndex(for: focusDay)
        if selectedPage != targetPage {
            selectedPage = targetPage
        }
    }
    
    private func claimReward(_ rewards: AchievementDef.Rewards) {
        claimedBaseRewards = rewards
        claimedRewards = store.combinedRewardForNextClaim() ?? rewards
        showClaimAnimation = true
        store.claimDailyReward()
        gameStore.achievementEvaluator?.onDailyClaimed()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showClaimAnimation = false
                claimedRewards = nil
            }
        }
    }

    private var weekNavigator: some View {
        let maxPage = 115  // Covers 2+ years

        return HStack(spacing: 12) {
            Button {
                if selectedPage > 0 {
                    withAnimation { selectedPage -= 1 }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(selectedPage > 0 ? .primary : .tertiary)
            }
            .disabled(selectedPage == 0)

            Menu {
                // Weeks 1-52
                ForEach(0..<52, id: \.self) { page in
                    Button("Week \(page + 1)") {
                        store.ensureClaimsCovering(pageIndex: page)
                        withAnimation { selectedPage = page }
                    }
                }
                // Day 365 (Year 1)
                Button("Day 365") {
                    store.ensureClaimsCovering(pageIndex: 52)
                    withAnimation { selectedPage = 52 }
                }
                // Weeks 53-104
                ForEach(53...104, id: \.self) { page in
                    Button("Week \(page)") {
                        store.ensureClaimsCovering(pageIndex: page)
                        withAnimation { selectedPage = page }
                    }
                }
                // Week 105 (Day 729)
                Button("Week 105") {
                    store.ensureClaimsCovering(pageIndex: 105)
                    withAnimation { selectedPage = 105 }
                }
                // Day 730 (Year 2)
                Button("Day 730") {
                    store.ensureClaimsCovering(pageIndex: 106)
                    withAnimation { selectedPage = 106 }
                }
                // Rest of Week 105 (Days 731-735)
                Button("Week 105 (cont.)") {
                    store.ensureClaimsCovering(pageIndex: 107)
                    withAnimation { selectedPage = 107 }
                }
                // Weeks 106+ (pages 108+)
                ForEach(108...maxPage, id: \.self) { page in
                    let weekNum = page - 2  // Offset by 2 for the extra pages
                    Button("Week \(weekNum)") {
                        store.ensureClaimsCovering(pageIndex: page)
                        withAnimation { selectedPage = page }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(pageLabel(for: selectedPage))
                        .font(.subheadline.bold())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Button {
                if selectedPage < maxPage {
                    store.ensureClaimsCovering(pageIndex: selectedPage + 1)
                    withAnimation { selectedPage += 1 }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(selectedPage < maxPage ? .primary : .tertiary)
            }
            .disabled(selectedPage >= maxPage)
        }
    }

    private func pageLabel(for page: Int) -> String {
        if page < 52 {
            return "Week \(page + 1)"
        } else if page == 52 {
            return "Day 365"
        } else if page <= 104 {
            return "Week \(page)"  // Pages 53-104 = Weeks 53-104
        } else if page == 105 {
            return "Week 105"  // Day 729
        } else if page == 106 {
            return "Day 730"
        } else if page == 107 {
            return "Week 105 (cont.)"  // Days 731-735
        } else {
            return "Week \(page - 2)"  // Pages 108+ = Weeks 106+ (offset by 2)
        }
    }
}

private struct WeekGridView: View {
    let claims: [DailyClaimsStore.DailyClaim]
    let currentClaimDay: Int
    let highlightDay: Int
    let nextDay: Int?
    let combinedRewardForNext: AchievementDef.Rewards?
    let onClaim: (DailyClaimsStore.DailyClaim) -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Grid of days in 2 columns
            let pairCount = claims.count / 2
            let hasOddDay = claims.count % 2 == 1

            // First 6 days (or pairs) in 2-column grid
            ForEach(0..<pairCount, id: \.self) { rowIndex in
                HStack(spacing: 12) {
                    let leftIndex = rowIndex * 2
                    let rightIndex = rowIndex * 2 + 1

                    DayGridCell(
                        claim: claims[leftIndex],
                        currentClaimDay: currentClaimDay,
                        highlightDay: highlightDay,
                        isNext: claims[leftIndex].day == nextDay,
                        combinedReward: claims[leftIndex].day == nextDay ? combinedRewardForNext : nil,
                        onClaim: claims[leftIndex].isAvailable ? { onClaim(claims[leftIndex]) } : nil
                    )
                    .frame(maxHeight: .infinity)

                    DayGridCell(
                        claim: claims[rightIndex],
                        currentClaimDay: currentClaimDay,
                        highlightDay: highlightDay,
                        isNext: claims[rightIndex].day == nextDay,
                        combinedReward: claims[rightIndex].day == nextDay ? combinedRewardForNext : nil,
                        onClaim: claims[rightIndex].isAvailable ? { onClaim(claims[rightIndex]) } : nil
                    )
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
            }

            // Last day centered (Day 7 or odd remaining day)
            if hasOddDay, let lastClaim = claims.last {
                DayGridCell(
                    claim: lastClaim,
                    currentClaimDay: currentClaimDay,
                    highlightDay: highlightDay,
                    isNext: lastClaim.day == nextDay,
                    combinedReward: lastClaim.day == nextDay ? combinedRewardForNext : nil,
                    onClaim: lastClaim.isAvailable ? { onClaim(lastClaim) } : nil
                )
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

private struct DayGridCell: View {
    let claim: DailyClaimsStore.DailyClaim
    let currentClaimDay: Int
    let highlightDay: Int
    let isNext: Bool
    let combinedReward: AchievementDef.Rewards?
    let onClaim: (() -> Void)?

    private var displayRewards: AchievementDef.Rewards {
        combinedReward ?? claim.rewards
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day title
            HStack {
                Text("Day \(claim.day)")
                    .font(.title2.bold())
                if claim.day == highlightDay {
                    Text("Today")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                }
                Spacer()
                statusIndicator
            }

            // Rewards
            HStack(spacing: 6) {
                ForEach(displayRewards.entries.prefix(3), id: \.self) { entry in
                    HStack(spacing: 3) {
                        Image(systemName: entry.kind.iconName)
                            .foregroundStyle(entry.kind.iconColor)
                        Text("\(entry.amount)")
                    }
                    .font(.subheadline)
                }
                if displayRewards.entries.count > 3 {
                    Text("+\(displayRewards.entries.count - 3)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Claim button if available
            if let onClaim, claim.isAvailable {
                Button(action: onClaim) {
                    Text("Claim")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple.gradient, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if claim.isClaimed {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if !claim.isAvailable {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        }
    }

    private var backgroundColor: Color {
        if claim.isClaimed {
            return Color.green.opacity(0.12)
        } else if claim.isAvailable {
            return Color.yellow.opacity(0.15)
        } else {
            return Color(.secondarySystemBackground)
        }
    }

    private var borderColor: Color {
        if claim.isAvailable {
            return .yellow
        } else if claim.isClaimed {
            return .green.opacity(0.6)
        } else {
            return .gray.opacity(0.2)
        }
    }
}

private struct YearlyRewardPageView: View {
    let claim: DailyClaimsStore.DailyClaim
    let currentClaimDay: Int
    let yearNumber: Int
    let onClaim: (() -> Void)?

    private var targetDay: Int {
        yearNumber == 1 ? 365 : 730
    }

    private var requiredDay: Int {
        yearNumber == 1 ? 364 : 729
    }

    private var hasReachedTarget: Bool {
        currentClaimDay >= requiredDay || claim.isClaimed
    }

    private var yearlyRewardText: String {
        if yearNumber == 1 {
            return "YEARLY REWARD!\nWOOHOO!"
        } else {
            return "YEARLY REWARD \(yearNumber)!\nWOOHOO!"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Day \(targetDay)")
                .font(.system(size: 56, weight: .bold, design: .rounded))

            if hasReachedTarget {
                // Rewards with icons
                HStack(spacing: 12) {
                    ForEach(claim.rewards.entries, id: \.self) { entry in
                        HStack(spacing: 6) {
                            Image(systemName: entry.kind.iconName)
                                .foregroundStyle(entry.kind.iconColor)
                            Text("\(entry.amount) \(entry.kind.displayName)")
                        }
                        .font(.title2)
                    }
                }

                Text(yearlyRewardText)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.purple)

                // Claim button or status - directly under celebration text
                if claim.isClaimed {
                    Label("Claimed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2.bold())
                } else if let onClaim {
                    Button(action: onClaim) {
                        Text("Claim Yearly Reward")
                            .font(.title3.bold())
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Color.purple.gradient, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.title2)
                        Text("Come back tomorrow!")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                // Locked state - hasn't reached target yet
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Complete \(requiredDay) days\nto unlock this reward!")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("Day \(currentClaimDay) / \(requiredDay)")
                    .font(.headline)
                    .foregroundStyle(.purple)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.15), Color.purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [.yellow, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}

private struct DailyRewardRow: View {
    let claim: DailyClaimsStore.DailyClaim
    let currentClaimDay: Int
    let highlightDay: Int
    let combinedReward: AchievementDef.Rewards
    let bonusEntries: [AchievementDef.Rewards.Entry]
    let onClaim: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Day \(claim.day)")
                        .font(.headline)
                    if claim.day == highlightDay {
                        Text("Today")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                    }
                }
                
                RewardsTiny(rewards: combinedReward)
                    .font(.footnote)
                
                if !bonusEntries.isEmpty {
                    HStack(spacing: 6) {
                        Text("Bonus:")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        ForEach(bonusEntries, id: \.self) { entry in
                            RewardChip(entry: entry, style: .compact)
            }
        }
                }
            }
            
            Spacer()
            
            statusControl
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var statusControl: some View {
        if claim.isClaimed {
            Label("Claimed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline.bold())
        } else if let onClaim {
            Button(action: onClaim) {
                Text("Claim")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.purple.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .shadow(color: .purple.opacity(0.2), radius: 6, y: 3)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "clock")
                Text(claim.day <= currentClaimDay ? "Locked" : "Upcoming")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    private var backgroundColor: Color {
        if claim.isClaimed {
            return Color.green.opacity(0.12)
        } else if claim.isAvailable {
            return Color.yellow.opacity(0.15)
        } else {
            return Color(.secondarySystemBackground)
        }
    }
    
    private var borderColor: Color {
        if claim.isAvailable {
            return .yellow
        } else if claim.isClaimed {
            return .green.opacity(0.6)
        } else {
            return .gray.opacity(0.2)
        }
    }
}

private struct RewardsTiny: View {
    let rewards: AchievementDef.Rewards
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(rewards.entries, id: \.self) { entry in
                RewardChip(entry: entry, style: .compact)
            }
        }
    }
}

private struct TimerView: View {
    let timeRemaining: TimeInterval
    @State private var deadline: Date?
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(timeString)
            .onAppear {
                deadline = Date().addingTimeInterval(timeRemaining)
            }
            .onReceive(timer) { _ in
                now = Date()
            }
    }

    private var timeString: String {
        guard let deadline else {
            return String(format: "%02d:%02d:%02d", 0, 0, 0)
        }
        let remaining = max(0, deadline.timeIntervalSince(now))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct RewardsDisplay: View {
    let rewards: AchievementDef.Rewards
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rewards.entries, id: \.self) { entry in
                RewardChip(entry: entry, style: .detailed)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ClaimAnimationOverlay: View {
    let rewards: AchievementDef.Rewards
    let baseRewards: AchievementDef.Rewards?
    
    init(rewards: AchievementDef.Rewards, baseRewards: AchievementDef.Rewards? = nil) {
        self.rewards = rewards
        self.baseRewards = baseRewards
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce)
                
                Text("Reward Claimed!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                RewardsDisplay(rewards: rewards)
                    .font(.title3)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                if let base = baseRewards {
                    let bonus = bonusEntries(base: base, combined: rewards)
                    if !bonus.isEmpty {
                        VStack(spacing: 8) {
                            Text("Streak Bonus")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            HStack(spacing: 8) {
                                ForEach(bonus, id: \.self) { entry in
                                    RewardChip(entry: entry, style: .compact)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
    }
}

private struct RewardChip: View {
    enum Style {
        case compact
        case detailed
    }
    
    let entry: AchievementDef.Rewards.Entry
    let style: Style
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.kind.iconName)
                .foregroundStyle(entry.kind.iconColor)
            switch style {
            case .compact:
                Text(compactText)
                    .font(.caption)
                    .foregroundStyle(entry.kind.iconColor)
            case .detailed:
                VStack(alignment: .leading, spacing: 2) {
                    Text(detailedTitle)
                        .font(.subheadline.bold())
                    Text(entry.kind.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(style == .compact ? 4 : 8)
        .background(entry.kind.iconColor.opacity(0.12), in: Capsule())
    }
    
    private var compactText: String {
        return "\(entry.amount) \(entry.kind.displayName)"
    }
    
    private var detailedTitle: String {
        return "\(entry.amount) \(entry.kind.displayName)"
    }
}

private extension AchievementDef.Rewards.Entry.Kind {
    var iconName: String {
        switch self {
        case .gems: return "diamond.fill"
        case .spins: return "arrow.triangle.2.circlepath"
        case .hammers: return "hammer.fill"
        case .magnets: return "dot.radiowaves.left.and.right"
        case .swaps: return "arrow.2.squarepath"
        case .boost2x, .boost3x, .boost4x: return "bolt.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .gems: return .cyan
        case .spins: return .purple
        case .hammers: return .orange
        case .magnets: return .blue
        case .swaps: return .green
        case .boost2x: return .yellow
        case .boost3x: return .pink
        case .boost4x: return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .gems: return "Gems"
        case .spins: return "Spins"
        case .hammers: return "Hammers"
        case .magnets: return "MegaMerges"
        case .swaps: return "Swaps"
        case .boost2x: return "2× Boost"
        case .boost3x: return "3× Boost"
        case .boost4x: return "4× Boost"
        }
    }
    
    var subtitle: String {
        switch self {
        case .boost2x, .boost3x, .boost4x:
            return "Bonus multiplier"
        case .spins:
            return "Bonus spin"
        case .swaps:
            return "Swap power"
        case .hammers:
            return "Smash a tile"
        case .magnets:
            return "Pull matches"
        case .gems:
            return "Spend in shop"
        }
    }
    
    var isMultiplier: Bool {
        switch self {
        case .boost2x, .boost3x, .boost4x:
            return true
        default:
            return false
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index += size
        }
        return result
    }
}

private func bonusEntries(base: AchievementDef.Rewards, combined: AchievementDef.Rewards) -> [AchievementDef.Rewards.Entry] {
    var delta: [AchievementDef.Rewards.Entry.Kind: Int] = [:]
    func add(kind: AchievementDef.Rewards.Entry.Kind, baseAmount: Int?, combinedAmount: Int?) {
        let b = baseAmount ?? 0
        let c = combinedAmount ?? 0
        if c > b {
            delta[kind] = c - b
        }
    }
    add(kind: .gems, baseAmount: base.gems, combinedAmount: combined.gems)
    add(kind: .spins, baseAmount: base.spins, combinedAmount: combined.spins)
    add(kind: .hammers, baseAmount: base.hammers, combinedAmount: combined.hammers)
    add(kind: .magnets, baseAmount: base.magnets, combinedAmount: combined.magnets)
    add(kind: .swaps, baseAmount: base.swaps, combinedAmount: combined.swaps)
    add(kind: .boost2x, baseAmount: base.boost2x, combinedAmount: combined.boost2x)
    add(kind: .boost3x, baseAmount: base.boost3x, combinedAmount: combined.boost3x)
    add(kind: .boost4x, baseAmount: base.boost4x, combinedAmount: combined.boost4x)
    
    return delta.map { AchievementDef.Rewards.Entry(kind: $0.key, amount: $0.value) }
        .sorted { $0.kind.displayName < $1.kind.displayName }
}

