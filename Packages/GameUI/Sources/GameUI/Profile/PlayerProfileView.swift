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
                    masteryGrid
                    actions
                    syncFooter
                }
                .padding(16)
            }
            .refreshable {
                await model.load(using: client)
                updateTierStatsFromStore()
            }
            .navigationTitle("Player Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Customize") { model.showCustomize = true }
                    Button("Compare") { model.showCompare = true }
                }
            }
            .task { 
                await model.load(using: client)
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
                CompareView(friendCode: model.friendCode) 
            }
            .sheet(isPresented: $model.showRename) {
                RenameSheet(
                    current: model.playerName,
                    onSave: { newName in
                        await model.rename(to: newName, using: client)
                    }
                )
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $model.showCountryPicker) {
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
    }

    private func updateTierStatsFromStore() {
        model.tiers = TierStat.stats(from: gameStore.tierMasteryCounts)
    }
    
    // MARK: Sections

    private var identityHero: some View {
        HStack(alignment: .center, spacing: 16) {
            AvatarBadge(option: AvatarCatalog.option(for: model.avatarSystemName), size: 80)
                .onTapGesture { model.showCustomize = true }
                .accessibilityAction {
                    model.showCustomize = true
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(model.playerName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Button {
                        model.showRename = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit name")
                    
                    Button {
                        model.showCustomize = true
                    } label: {
                        Image(systemName: "pencil.tip.crop.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Customize avatar")
                }

                HStack(spacing: 8) {
                    Label(model.friendCode, systemImage: "person.badge.key.fill")
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .contextMenu {
                            Button("Copy Code") { 
                                #if os(iOS)
                                UIPasteboard.general.string = model.friendCode
                                #endif
                            }
                            ShareLink("Share Code", item: URL(string: "game2244://add-friend?code=\(model.friendCode)")!)
                        }
                }
                
                // Country and Highest Tile Row
                HStack(spacing: 8) {
                    // Country Selector
                    Button {
                        model.showCountryPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            if let countryCode = model.countryCode {
                                Text(flagEmoji(countryCode))
                                Text(countryName(countryCode))
                            } else {
                                Image(systemName: "globe")
                                Text("Select Country")
                            }
                        }
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Country selection")
                    
                    Spacer(minLength: 0)
                    
                    // Highest Tile Display
                    if let highestTile = model.highestTile {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                            Text(highestTile)
                                .font(.headline.weight(.bold))
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
        }
    }

    private var coreStats: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Best Score",
                value: model.bestScoreText,
                info: "Your highest single‑run score. Ties are broken by earliest time achieved."
            )
            StatCard(
                title: "Global Rank",
                value: "#\(String(model.globalRank))",
                info: "Your position on the world ladder. Updates after each run."
            )
        }
    }

    private var masteryGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tier Mastery")
                    .font(.headline)
                Spacer()
            }
            if model.tiers.isEmpty {
                Text("Make higher merges to unlock mastery stats.")
                    .font(.footnote)
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

    private var actions: some View {
        HStack(spacing: 12) {
            ShareLink(
                "Share",
                item: ShareableProfile(
                    payload: payload(),
                    deepLink: client.shareDeepLink(for: payload())
                ),
                preview: SharePreview(
                    "\(model.playerName)'s Profile",
                    image: Image(systemName: "person.crop.square.filled.and.at.rectangle")
                )
            )
            .buttonStyle(.borderedProminent)

            Button {
                model.showCompare = true
            } label: {
                Label("Compare", systemImage: "person.2.cross")
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
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
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
            }
            Spacer()
        }
        .font(.footnote)
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
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Image(systemName: "info.circle").help(info)
            }
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
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
                    .font(.headline.weight(.bold))
                    .fontDesign(tier.usesCurvedLStyling ? .rounded : .default)
                    .foregroundStyle(.white)
            }
            Text("\(tier.value)")
                .font(.headline.monospacedDigit())
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

    private let popularCountries = [
        "US", "GB", "CA", "AU", "DE", "FR", "JP", "IN", "BR", "MX",
        "CN", "KR", "IT", "ES", "NL", "SE", "CH", "NO", "DK", "FI",
        "PL", "BE", "AT", "IE", "PT", "GR", "CZ", "RO", "HU", "NZ",
        "SG", "MY", "TH", "PH", "ID", "VN", "AE", "SA", "IL", "TR",
        "ZA", "NG", "EG", "KE", "AR", "CL", "CO", "PE", "VE"
    ]

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
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
                .background(Color(.systemGray6))
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
                                Text("No Country")
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
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
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
                Text(countryName(countryCode))
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
        let locale = Locale.current
        return locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    private var allCountryCodes: [String] {
        if #available(iOS 16.0, *) {
            return Locale.Region.isoRegions.compactMap { $0.identifier }.sorted { countryName($0) < countryName($1) }
        } else {
            return Locale.isoRegionCodes.sorted { countryName($0) < countryName($1) }
        }
    }
}

// MARK: - Helper Extensions

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}