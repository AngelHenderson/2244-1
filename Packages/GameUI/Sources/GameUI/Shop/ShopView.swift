import SwiftUI
import GameApp
import GameCore

// MARK: - Weekly Offer Sheet

public struct WeeklyOfferSheet: View {
    @Environment(\.shopStore) private var shopStore
    @Environment(\.dismiss) private var dismiss
    @State private var timeRemaining: String = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var offer: WeeklyOfferManager.WeeklyOffer {
        WeeklyOfferManager.currentOffer()
    }

    private var deadline: Date {
        WeeklyOfferManager.currentOfferDeadline()
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Countdown header
                    VStack(spacing: 8) {
                        Text("LIMITED TIME OFFER")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(2)

                        Text(offer.title)
                            .font(.avenirNext(size: GameFonts.largeTitleSize, weight: .bold))

                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text("Ends in \(timeRemaining)")
                                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.orange.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .padding(.top)

                    // Offer contents
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's Included")
                            .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            if offer.noAdsLifetime {
                                noAdsRow(text: "No Ads Lifetime")
                                Divider().padding(.leading, 52)
                            } else if offer.noAds {
                                noAdsRow(text: "No Ads")
                                Divider().padding(.leading, 52)
                            }
                            if let gems = offer.gems {
                                offerRow(icon: "gem", text: "\(gems.formatted()) Gems", color: .clear)
                                Divider().padding(.leading, 52)
                            }
                            if let hammers = offer.hammers {
                                offerRow(icon: "hammer", text: "\(hammers) Hammers", color: .clear)
                                Divider().padding(.leading, 52)
                            }
                            if let swaps = offer.swaps {
                                offerRow(icon: "swap", text: "\(swaps) Swaps", color: .clear)
                                Divider().padding(.leading, 52)
                            }
                            if let magnets = offer.magnets {
                                offerRow(icon: "magnet", text: "\(magnets) MegaMerges", color: .clear)
                                Divider().padding(.leading, 52)
                            }
                            if let spins = offer.spins {
                                offerRow(icon: "spinthewheel", text: "\(spins) Spins", color: .clear)
                                Divider().padding(.leading, 52)
                            }
                            if let boost2x = offer.boost2x {
                                offerRow(icon: "boost2x", text: "\(boost2x) 2X Boost", color: .clear)
                                Divider().padding(.leading, 52)
                            }
                            if let boost3x = offer.boost3x {
                                offerRow(icon: "3.circle.fill", text: "\(boost3x) 3X Boost", color: .orange)
                                Divider().padding(.leading, 52)
                            }
                            if let boost4x = offer.boost4x {
                                offerRow(icon: "4.circle.fill", text: "\(boost4x) 4X Boost", color: .red)
                            }
                        }
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)

                    // Purchase button
                    Button {
                        Task {
                            await shopStore.purchase(offer.id)
                            dismiss()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Get This Offer")
                                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                            Text(offer.formattedPrice)
                                .font(.avenirNext(size: GameFonts.title1Size, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(shopStore.isPurchased(offer.id) || shopStore.isPurchasing)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Best Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.avenirNext(size: GameFonts.bodySize, weight: .semibold))
                }
            }
        }
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
        .overlay {
            if shopStore.isPurchasing {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }

    private func offerRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 16) {
            if icon == "gem" || icon == "hammer" || icon == "swap" || icon == "magnet" || icon == "spinthewheel" || icon == "boost2x" {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 36)
            } else {
                Image(systemName: icon)
                    .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
                    .foregroundStyle(color)
                    .frame(width: 36)
            }

            Text(text)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }

    private func noAdsRow(text: String) -> some View {
        HStack(spacing: 16) {
            NoAdsIcon()
                .frame(width: 36, height: 36)

            Text(text)
                .font(.avenirNext(size: GameFonts.bodySize, weight: .regular))

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }

    private func updateTimeRemaining() {
        let interval = deadline.timeIntervalSince(Date())
        guard interval > 0 else {
            timeRemaining = "Expired"
            return
        }

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if days > 0 {
            timeRemaining = "\(days)d \(hours)h \(minutes)m \(seconds)s"
        } else if hours > 0 {
            timeRemaining = "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            timeRemaining = "\(minutes)m \(seconds)s"
        } else {
            timeRemaining = "\(seconds)s"
        }
    }
}

// MARK: - Shop View

public struct ShopView: View {
    @Environment(\.shopStore) private var shopStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = ShopTab.bundles
    
    public enum ShopTab: String, CaseIterable {
        case bundles = "Bundles"
        case gems = "Gems"
        case perks = "Perks"

        var icon: String {
            switch self {
            case .bundles: return "mysterybox"
            case .gems: return "gem"
            case .perks: return "gift"
            }
        }
    }
    
    public init(initialTab: ShopTab = .bundles) {
        self._selectedTab = State(initialValue: initialTab)
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(ShopTab.allCases, id: \.self) { tab in
                            TabButton(
                                title: tab.rawValue,
                                icon: tab.icon,
                                isSelected: selectedTab == tab
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .bundles:
                            bundlesSection
                        case .gems:
                            gemsSection

                        case .perks:
                            perksSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        GemBalancePill()
                        Button("Done") { dismiss() }
                            .font(.avenirNext(size: GameFonts.bodySize, weight: .semibold))
                    }
                }
            }
        }
        .overlay {
            if shopStore.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassBackground()
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var bundlesSection: some View {
        VStack(spacing: 20) {
            // Weekly Best Offer at the top
            WeeklyOfferCard()

            // Regular bundles
            if let bundles = shopStore.catalog?.bundles {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(bundles) { bundle in
                        BundleCard(bundle: bundle)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var gemsSection: some View {
        if let gems = shopStore.catalog?.gemBundles {
            VStack(spacing: 12) {
                ForEach(gems.sorted(by: { $0.gems < $1.gems })) { gem in
                    GemBundleRow(gem: gem)
                }
            }
        }
    }
    
    @ViewBuilder
    private var perksSection: some View {
        VStack(spacing: 20) {
            if let perks = shopStore.catalog?.perkBundles {
                ForEach(Dictionary(grouping: perks, by: { $0.item }).sorted(by: { $0.key < $1.key }), id: \.key) { item, bundles in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.lowercased() == "magnet" ? "MegaMerges" : "\(item.capitalized)s")
                            .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))

                        VStack(spacing: 10) {
                            ForEach(bundles.sorted(by: { $0.quantity < $1.quantity })) { perk in
                                PerkBundleRow(perk: perk)
                            }
                        }
                    }
                }
            }
            
            FreePerksSection()
        }
    }
}

// MARK: - Component Views

struct WeeklyOfferCard: View {
    @Environment(\.shopStore) private var shopStore
    @State private var timeRemaining: String = ""
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var offer: WeeklyOfferManager.WeeklyOffer {
        WeeklyOfferManager.currentOffer()
    }

    private var deadline: Date {
        WeeklyOfferManager.currentOfferDeadline()
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with countdown
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("BEST OFFER")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                    Text(offer.title)
                        .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ends in")
                        .font(.avenirNext(size: GameFonts.caption2Size, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(timeRemaining)
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }

            // Contents
            VStack(alignment: .leading, spacing: 6) {
                if offer.noAdsLifetime {
                    HStack(spacing: 8) {
                        NoAdsIcon()
                            .frame(width: 20, height: 20)
                        Text("No Ads Lifetime")
                            .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                    }
                } else if offer.noAds {
                    HStack(spacing: 8) {
                        NoAdsIcon()
                            .frame(width: 20, height: 20)
                        Text("No Ads")
                            .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                    }
                }
                if let gems = offer.gems {
                    Label {
                        Text(verbatim: "\(gems.formatted()) Gems")
                    } icon: {
                        Image("gem").resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
                if let hammers = offer.hammers {
                    Label {
                        Text(verbatim: "\(hammers) Hammers")
                    } icon: {
                        Image("hammer").resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
                if let swaps = offer.swaps {
                    Label {
                        Text(verbatim: "\(swaps) Swaps")
                    } icon: {
                        Image("swap").resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
                if let magnets = offer.magnets {
                    Label {
                        Text(verbatim: "\(magnets) MegaMerges")
                    } icon: {
                        Image("magnet").resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
                if let spins = offer.spins {
                    Label {
                        Text(verbatim: "\(spins) Spins")
                    } icon: {
                        Image("spinthewheel").resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
                if let boost2x = offer.boost2x {
                    Label {
                        Text(verbatim: "\(boost2x) 2X Boost")
                    } icon: {
                        Image("boost2x")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
                if let boost3x = offer.boost3x {
                    Label {
                        Text(verbatim: "\(boost3x) 3X Boost")
                    } icon: {
                        Image(systemName: "3.circle.fill")
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
                if let boost4x = offer.boost4x {
                    Label {
                        Text(verbatim: "\(boost4x) 4X Boost")
                    } icon: {
                        Image(systemName: "4.circle.fill")
                    }
                    .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .regular))
                }
            }

            // Purchase button
            Button {
                Task { await shopStore.purchase(offer.id) }
            } label: {
                Text(offer.formattedPrice)
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(shopStore.isPurchased(offer.id) || shopStore.isPurchasing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.6), .yellow.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .onAppear {
            updateTimeRemaining()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
    }

    private func updateTimeRemaining() {
        timeRemaining = WeeklyOfferManager.countdownString(to: deadline)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct BundleCard: View {
    let bundle: ShopBundle
    @Environment(\.shopStore) private var shopStore
    
    var body: some View {
        VStack(spacing: 12) {
            // Tags
            if let tags = bundle.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        TagView(text: tag, style: tagStyle(for: tag))
                    }
                }
            }
            
            Text(bundle.title)
                .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                .multilineTextAlignment(.center)
            
            // Items preview
            VStack(alignment: .leading, spacing: 4) {
                if let items = bundle.items {
                    if let gems = items.gems {
                        Label {
                            Text(verbatim: "\(gems) Gems")
                        } icon: {
                            Image("gem")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                    if let hammers = items.hammers {
                        Label {
                            Text(verbatim: "\(hammers) Hammers")
                        } icon: {
                            Image("hammer")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                    if let swaps = items.swaps {
                        Label {
                            Text(verbatim: "\(swaps) Swaps")
                        } icon: {
                            Image("swap")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                    if let magnets = items.magnets {
                        Label {
                            Text(verbatim: "\(magnets) MegaMerges")
                        } icon: {
                            Image("magnet")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                    if let spins = items.spins {
                        Label {
                            Text(verbatim: "\(spins) Spins")
                        } icon: {
                            Image("spinthewheel")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                    if let boost2x = items.boost2x {
                        Label {
                            Text(verbatim: "\(boost2x) 2X Boost")
                        } icon: {
                            Image("boost2x")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                    if let boost3x = items.boost3x {
                        Label {
                            Text(verbatim: "\(boost3x) 3X Boost")
                        } icon: {
                            Image(systemName: "3.circle.fill")
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                    if let boost4x = items.boost4x {
                        Label {
                            Text(verbatim: "\(boost4x) 4X Boost")
                        } icon: {
                            Image(systemName: "4.circle.fill")
                        }
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                }
                if bundle.perks?.noAds == true {
                    HStack(spacing: 6) {
                        NoAdsIcon()
                            .frame(width: 16, height: 16)
                        Text("No Ads")
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                    }
                }
            }
            
            Spacer()
            
            Button {
                Task { await shopStore.purchase(bundle.id) }
            } label: {
                Text(shopStore.formatPrice(bundle.price))
                    .font(.avenirNext(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(shopStore.isPurchased(bundle.id) ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(shopStore.isPurchased(bundle.id) || shopStore.isPurchasing)
        }
        .padding()
        .frame(minHeight: 200)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func tagStyle(for tag: String) -> TagView.TagStyle {
        switch tag.lowercased() {
        case "best value": return .success
        case "50% off": return .warning
        case "whale": return .premium
        case "seasonal": return .seasonal
        default: return .default
        }
    }
}

struct GemBundleRow: View {
    let gem: GemBundle
    @Environment(\.shopStore) private var shopStore

    var body: some View {
        Button {
            Task { await shopStore.purchase(gem.id) }
        } label: {
            HStack(spacing: 12) {
                gemIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(gem.gems.formatted()) Gems")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                    if let tag = gem.tags?.first {
                        Text(tag)
                            .font(.avenirNext(size: GameFonts.caption1Size, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(shopStore.formatPrice(gem.price))
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(shopStore.isPurchasing)
        .accessibilityLabel("\(gem.gems) gems for \(shopStore.formatPrice(gem.price))")
    }

    private var gemIcon: Image {
        #if canImport(UIKit)
        if let path = Bundle.module.path(forResource: "GemBagIcon", ofType: "png"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        #elseif canImport(AppKit)
        if let path = Bundle.module.path(forResource: "GemBagIcon", ofType: "png"),
           let nsImage = NSImage(contentsOfFile: path) {
            return Image(nsImage: nsImage)
        }
        #endif
        return Image("gem")
    }
}

struct PerkBundleRow: View {
    let perk: PerkBundle
    @Environment(\.shopStore) private var shopStore

    var body: some View {
        Button {
            Task { await shopStore.purchase(perk.id) }
        } label: {
            HStack(spacing: 12) {
                perkIcon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(perk.quantity) \(perkDisplayName):")
                        .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                }
                Spacer()
                Text(shopStore.formatPrice(perk.price))
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(shopStore.isPurchasing)
        .accessibilityLabel("\(perk.quantity) \(perkDisplayName) for \(shopStore.formatPrice(perk.price))")
    }

    private var perkDisplayName: String {
        switch perk.item.lowercased() {
        case "hammer": return perk.quantity == 1 ? "Hammer" : "Hammers"
        case "swap": return perk.quantity == 1 ? "Swap" : "Swaps"
        case "magnet": return perk.quantity == 1 ? "MegaMerge" : "MegaMerges"
        default: return perk.item.capitalized
        }
    }

    private var perkIcon: Image {
        switch perk.item.lowercased() {
        case "hammer": return Image("hammer")
        case "swap": return Image("swap")
        case "magnet": return Image("magnet")
        default: return Image(systemName: "star.fill")
        }
    }
}


struct FreePerksSection: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle().fill(Color.primary.opacity(0.2)).frame(height: 2)
                Text("FREE PERKS")
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .bold))
                Rectangle().fill(Color.primary.opacity(0.2)).frame(height: 2)
            }
            .padding(.top, 10)
            
            VStack(spacing: 12) {
                FreePerkRow(icon: "hammer")
                FreePerkRow(icon: "swap")
                FreePerkRow(icon: "magnet")
            }
        }
    }
}

struct FreePerkRow: View {
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(.leading, 16)
            
            // Central number pill
            Text("01")
                .font(.avenirNext(size: GameFonts.title2Size, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 4)
                .background(Color(red: 0.0, green: 0.6, blue: 0.6))
                .clipShape(Capsule())
            
            Spacer()
            
            // Action button
            Button {
                // Future action to claim free perk
            } label: {
                Text("Free")
                    .font(.avenirNext(size: GameFonts.title3Size, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .frame(width: 100)
                    .background(Color(red: 0.1, green: 0.7, blue: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.8), lineWidth: 2)
                    )
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.9, blue: 0.9), Color(red: 0.0, green: 0.7, blue: 0.85)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            // Notification dot
            Image(systemName: "exclamationmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
                .font(.system(size: 20))
                .offset(x: 8, y: -8)
        }
    }
}

struct TagView: View {
    let text: String
    let style: TagStyle

    enum TagStyle {
        case `default`, success, warning, premium, seasonal

        var backgroundColor: Color {
            switch self {
            case .default: return .gray.opacity(0.2)
            case .success: return .green.opacity(0.2)
            case .warning: return .orange.opacity(0.2)
            case .premium: return .purple.opacity(0.2)
            case .seasonal: return .pink.opacity(0.2)
            }
        }

        var foregroundColor: Color {
            switch self {
            case .default: return .primary
            case .success: return .green
            case .warning: return .orange
            case .premium: return .purple
            case .seasonal: return .pink
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.avenirNext(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.backgroundColor)
            .foregroundStyle(style.foregroundColor)
            .clipShape(Capsule())
    }
}

/// Custom "No Ads" icon showing "ADS" text with a prohibition symbol overlay
struct NoAdsIcon: View {
    var body: some View {
        ZStack {
            // "ADS" text
            Text("ADS")
                .font(.avenirNext(size: 12, weight: .heavy))
                .foregroundStyle(.blue)

            // Prohibition circle and line overlay
            Circle()
                .stroke(Color.red, lineWidth: 3)

            // Diagonal line
            Rectangle()
                .fill(Color.red)
                .frame(width: 3)
                .rotationEffect(.degrees(45))
        }
    }
}