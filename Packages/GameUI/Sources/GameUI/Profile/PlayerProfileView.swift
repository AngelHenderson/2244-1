import SwiftUI
import GameApp

@MainActor
public struct PlayerProfileView: View {
    @Environment(\.profileClient) private var client
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameStore) private var gameStore
    @State private var model = ProfileModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    identityHero
                    coreStats
                    globalRankCard
                    seasonCard
                    masteryGrid
                    syncFooter
                }
                .padding(16)
            }
            .refreshable {
                await model.load(using: client)
                updateTierStatsFromStore()
            }
            .navigationTitle("Player Profile")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .platformTopBarTrailing) {
                    GemBalancePill()
                }
            }
            .task {
                await model.load(using: client)
                updateTierStatsFromStore()
            }
            .onAppear {
                // Also load tiers synchronously on appear to ensure they're always fresh
                updateTierStatsFromStore()
            }
            .sheet(isPresented: $model.showCustomize) {
                AvatarCustomizeView(
                    currentAvatar: model.avatarSystemName,
                    onSelect: { newAvatar in
                        model.avatarSystemName = newAvatar
                    }
                )
            }
            .sheet(isPresented: $model.showCompare) {
                CompareView(
                    friendCode: model.friendCode,
                    myProfile: CompareProfile(
                        name: model.playerName,
                        score: model.bestScoreText,
                        milestone: model.highestTile ?? "—",
                        countryFlag: flagEmoji(model.countryCode ?? ""),
                        avatar: model.avatarSystemName
                    )
                )
            }
            .sheet(isPresented: $model.showRename) {
                RenameSheet(
                    current: model.playerName,
                    onSave: { newName in
                        await model.rename(to: newName, using: client)
                    }
                )
            }
            .sheet(isPresented: $model.showSeasonHistory) {
                SeasonHistoryView(season: model.season, playerSeed: model.friendCode)
            }
            #if os(iOS)
            .platformFullScreenCover(isPresented: $model.showCountryPicker) {
                CountryPickerView(
                    selectedCountry: model.countryCode,
                    onSelect: { countryCode in
                        Task {
                            await model.updateCountry(to: countryCode, using: client)
                        }
                    }
                )
            }
            #else
            .sheet(isPresented: $model.showCountryPicker) {
                CountryPickerView(
                    selectedCountry: model.countryCode,
                    onSelect: { countryCode in
                        Task {
                            await model.updateCountry(to: countryCode, using: client)
                        }
                    }
                )
            }
            #endif
            .onChange(of: gameStore.tierMasteryCounts) { _, _ in
                updateTierStatsFromStore()
            }
        }
        .trackScreen(.profile)
    }

    private func updateTierStatsFromStore() {
        model.tiers = TierStat.stats(from: gameStore.tierMasteryCounts)
    }
    
    // MARK: Sections

    private var identityHero: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 12) {
                // Country picker on far left
                Button {
                    model.showCountryPicker = true
                } label: {
                    HStack(spacing: 6) {
                        if let countryCode = model.countryCode {
                            Text(flagEmoji(countryCode))
                                .font(.system(size: 28))
                            Text(countryName(countryCode))
                                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .medium))
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 24))
                            Text("Select Country")
                                .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .medium))
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Country selection")
                
                Spacer(minLength: 0)
                
                // Center profile column (50% width)
                VStack(spacing: 4) {
                    Text("Player Name")
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .center, spacing: 10) {
                        AvatarBadge(option: AvatarCatalog.option(for: model.avatarSystemName), size: 50)
                            .onTapGesture { model.showCustomize = true }
                            .accessibilityAction {
                                model.showCustomize = true
                            }

                        Text(model.playerName)
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer(minLength: 0)
                        
                        // Edit name button
                        Button {
                            model.showRename = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit name")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassBackground(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(width: geometry.size.width * 0.5)
                
                Spacer(minLength: 0)
                
                #if DEBUG
                // Preview/debug comparison uses synthetic players and is not shipped.
                Button {
                    model.showCompare = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2")
                            .font(.system(size: 20))
                        Text("Compare")
                            .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Compare with friends")
                #endif
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 66)
    }
    
    private var coreStats: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                // Left column: Code + Best Score
                VStack(spacing: 8) {
                    // Friend Code
                    Label(model.friendCode, systemImage: "person.badge.key.fill")
                        .font(.avenirNext(size: GameFonts.calloutSize, weight: .medium))
                        .foregroundStyle(.secondary)
                        .contextMenu {
                            Button("Copy Code") { 
                                #if os(iOS)
                                UIPasteboard.general.string = model.friendCode
                                #endif
                            }
                            ShareLink("Share Code", item: URL(string: "game2244://add-friend?code=\(model.friendCode)")!)
                        }
                    
                    // Best Score card
                    VStack(alignment: .center, spacing: 6) {
                        Text("Best Score")
                            .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text(model.bestScoreText)
                            .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .glassBackground(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                // Right column: Share + Best Milestone
                VStack(spacing: 8) {
                    // Share button
                    ShareLink(
                        item: ShareableProfile(
                            payload: payload(),
                            deepLink: client.shareDeepLink(for: payload())
                        ),
                        preview: SharePreview(
                            "\(model.playerName)'s Profile",
                            image: Image(systemName: "person.crop.square.filled.and.at.rectangle")
                        )
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.avenirNext(size: GameFonts.calloutSize, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Best Milestone card
                    VStack(alignment: .center, spacing: 6) {
                        Text("Best Milestone")
                            .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 14))
                            Text(model.highestTile ?? "—")
                                .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .glassBackground(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(width: geometry.size.width * 0.5)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 95)
    }
    
    private var seasonCard: some View {
        Button {
            model.showSeasonHistory = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.season.name)
                        .font(.avenirNext(size: GameFonts.calloutSize, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(model.season.division)
                        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("History")
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .medium))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .glassBackground(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var globalRankCard: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 6) {
                Text("Global Rank")
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("#\(model.globalRank)")
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
            }
            .padding(.vertical, 10)
            .frame(width: geometry.size.width * 0.25)
            .glassBackground(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity)
        }
        .frame(height: 60)
    }

    private var masteryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tier Mastery")
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                Spacer()
            }
            if model.tiers.isEmpty {
                Text("Make higher merges to unlock mastery stats.")
                    .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(model.tiers) { tier in
                        TierCard(tier: tier)
                    }
                }
            }
        }
    }

    private var syncFooter: some View {
        HStack(spacing: 6) {
            switch model.sync {
            case .syncing:
                ProgressView().controlSize(.mini)
                Text("Syncing…").foregroundStyle(.secondary)
            case .synced(let date):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Synced • \(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now))")
                    .foregroundStyle(.secondary)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message).foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        await model.load(using: client)
                    }
                }
                .font(.avenirNext(size: GameFonts.footnoteSize, weight: .medium))
                .buttonStyle(.borderless)
            }
            Spacer()
        }
        .font(.avenirNext(size: GameFonts.footnoteSize, weight: .regular))
        .padding(.top, 8)
    }

    private func payload() -> ProfilePayload {
        .init(
            playerName: model.playerName,
            bestScoreText: model.bestScoreText,
            globalRank: model.globalRank,
            tiers: model.tiers,
            friendCode: model.friendCode,
            season: model.season,
            avatarSystemName: model.avatarSystemName,
            countryCode: model.countryCode,
            highestTile: model.highestTile
        )
    }
    
    // MARK: - Helper Functions

    private func flagEmoji(_ countryCode: String) -> String {
        let uppercased = countryCode.uppercased()
        let regionalIndicatorBase: UInt32 = 0x1F1E6 // 🇦
        let asciiA: UInt32 = 0x41 // A

        return uppercased.unicodeScalars.compactMap { scalar in
            guard scalar.value >= asciiA && scalar.value <= 0x5A else { return nil } // A-Z range
            let offset = scalar.value - asciiA
            return UnicodeScalar(regionalIndicatorBase + offset)
        }
        .map(String.init)
        .joined()
    }

    private func countryName(_ countryCode: String) -> String {
        if countryCode.uppercased() == "US" { return "US" }
        if countryCode.uppercased() == "GB" { return "UK" }
        let locale = Locale.current
        return locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }
}

// MARK: - Components

private struct StatCard: View {
    var title: String
    var value: String
    var info: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular)).foregroundStyle(.secondary)
                Image(systemName: "info.circle").help(info)
            }
            Text(value).font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TierCard: View {
    var tier: TierStat
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tier.color.opacity(0.9))
                    .frame(width: 36, height: 36)
                Text(tier.displayKey)
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("\(tier.value)")
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .help(tier.label)
    }
}

// MARK: - Country Picker

private struct CountryPickerView: View {
    let selectedCountry: String?
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    // Countries with leaderboards, sorted by player count (popularity)
    private var popularCountries: [String] {
        MockLeaderboardData.countriesWithLeaderboardsSortedByPopularity()
    }

    private var filteredPopularCountries: [String] {
        if searchText.isEmpty {
            return popularCountries
        }
        return popularCountries.filter { countryCode in
            let name = countryName(countryCode).lowercased()
            let code = countryCode.lowercased()
            let search = searchText.lowercased()
            return name.contains(search) || code.contains(search)
        }
    }

    private var filteredAllCountries: [String] {
        let allExcludingPopular = allCountryCodes.filter { !popularCountries.contains($0) }
        if searchText.isEmpty {
            return allExcludingPopular
        }
        return allExcludingPopular.filter { countryCode in
            let name = countryName(countryCode).lowercased()
            let code = countryCode.lowercased()
            let search = searchText.lowercased()
            return name.contains(search) || code.contains(search)
        }
    }

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar with keyboard support
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search countries", text: $searchText)
                        .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .platformTextInputAutocapitalizationNever()
                        .focused($isSearchFocused)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    Section {
                        Button {
                            onSelect(nil)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 20))
                                Text("No Country")
                                    .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                                Spacer()
                                if selectedCountry == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }

                    if !filteredPopularCountries.isEmpty {
                        Section("Popular Countries") {
                            ForEach(filteredPopularCountries, id: \.self) { countryCode in
                                countryRow(countryCode: countryCode)
                            }
                        }
                    }

                    if !filteredAllCountries.isEmpty {
                        Section("All Countries") {
                            ForEach(filteredAllCountries, id: \.self) { countryCode in
                                countryRow(countryCode: countryCode)
                            }
                        }
                    }
                }
                .platformInsetGroupedListStyle()
            }
            .navigationTitle("Select Country")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }
    
    private func countryRow(countryCode: String) -> some View {
        Button {
            onSelect(countryCode)
            dismiss()
        } label: {
            HStack {
                Text(flagEmoji(countryCode))
                    .font(.system(size: 20))
                Text(countryName(countryCode))
                    .font(.avenirNext(size: GameFonts.bodySize, weight: .medium))
                Spacer()
                if selectedCountry == countryCode {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func flagEmoji(_ countryCode: String) -> String {
        let uppercased = countryCode.uppercased()
        let regionalIndicatorBase: UInt32 = 0x1F1E6 // 🇦
        let asciiA: UInt32 = 0x41 // A

        return uppercased.unicodeScalars.compactMap { scalar in
            guard scalar.value >= asciiA && scalar.value <= 0x5A else { return nil } // A-Z range
            let offset = scalar.value - asciiA
            return UnicodeScalar(regionalIndicatorBase + offset)
        }
        .map(String.init)
        .joined()
    }

    private func countryName(_ countryCode: String) -> String {
        if countryCode.uppercased() == "US" { return "US" }
        if countryCode.uppercased() == "GB" { return "UK" }
        let locale = Locale.current
        return locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    // Codes that are not actual countries (continents, regions, organizations, etc.)
    private let excludedCodes: Set<String> = [
        "EU", "EZ", "UN", "QO", "ZZ",  // Organizations and special codes
        "AC", "CP", "DG", "EA", "IC", "TA",  // Minor territories
        // Numeric codes for continents/regions
        "001", "002", "003", "005", "009", "011", "013", "014", "015", "017", "018", "019",
        "021", "029", "030", "034", "035", "039", "053", "054", "057", "061",
        "142", "143", "145", "150", "151", "154", "155", "202", "419"
    ]

    // Filter out entries that don't have valid flag emojis (regions show as text without flags)
    private func isValidCountry(_ code: String) -> Bool {
        // Exclude codes in the exclusion list
        if excludedCodes.contains(code) { return false }
        // Exclude 3-digit numeric codes (regions)
        if code.count == 3 && code.allSatisfy({ $0.isNumber }) { return false }
        // Only include 2-letter codes that produce valid flags
        if code.count != 2 { return false }
        return true
    }

    private var allCountryCodes: [String] {
        let codes: [String]
        if #available(iOS 16.0, *) {
            codes = Locale.Region.isoRegions.compactMap { $0.identifier }
        } else {
            codes = Locale.isoRegionCodes
        }
        return codes
            .filter { isValidCountry($0) }
            .sorted { countryName($0) < countryName($1) }
    }
}

// MARK: - Helper Extensions

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
