import SwiftUI
import GameApp
import GameCore

public struct ShopView: View {
    @Environment(\.shopStore) private var shopStore
    @Environment(\.tileJourney) private var journeyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = ShopTab.bundles
    
    public enum ShopTab: String, CaseIterable {
        case bundles = "Bundles"
        case gems = "Gems"
        case journey = "Journey"
        case perks = "Perks"
        case special = "Special"
        
        var icon: String {
            switch self {
            case .bundles: return "cube.box.fill"
            case .gems: return "diamond.fill"
            case .journey: return "map.fill"
            case .perks: return "star.fill"
            case .special: return "gift.fill"
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
                        case .journey:
                            journeySection
                        case .perks:
                            perksSection
                        case .special:
                            specialSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .overlay {
            if shopStore.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var bundlesSection: some View {
        if let bundles = shopStore.catalog?.bundles {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(bundles) { bundle in
                    BundleCard(bundle: bundle)
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
    private var journeySection: some View {
        VStack(spacing: 24) {
            // Journey progress indicator
            JourneyProgressCard()
            
            // Available journey tiles
            VStack(alignment: .leading, spacing: 16) {
                Text("Journey Tiles")
                    .font(.headline)
                
                Text("Unlock tiles as you progress through milestones")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    let window = journeyWindow()
                    ForEach(Array(window.enumerated()), id: \.offset) { _, item in
                        JourneyTileView(
                            label: JourneyTileGenerator.formatTileAtStep(item.step),
                            isUnlocked: item.step <= item.currentStep
                        )
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    @ViewBuilder
    private var perksSection: some View {
        if let perks = shopStore.catalog?.perkBundles {
            VStack(spacing: 20) {
                ForEach(Dictionary(grouping: perks, by: { $0.item }).sorted(by: { $0.key < $1.key }), id: \.key) { item, bundles in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.lowercased() == "magnet" ? "MegaMerges" : item.capitalized)
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(bundles.sorted(by: { $0.quantity < $1.quantity })) { perk in
                                    PerkCard(perk: perk)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var specialSection: some View {
        if let specials = shopStore.catalog?.specialOffers {
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                ForEach(specials) { offer in
                    SpecialOfferCard(offer: offer)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func journeyWindow() -> [(step: Int, currentStep: Int)] {
        let highest = max(2, journeyStore.highestTile)
        // Derive the step index (step 0 == 2). Fallback to log2 for safety.
        let currentStep = Tile.makeFromValue(highest)?.stepIndex
            ?? max(0, Int(log2(Double(highest))) - 1)
        let start = max(0, currentStep - 20)
        let end = currentStep + 20
        return Array(start...end).map { (step: $0, currentStep: currentStep) }
    }
}

// MARK: - Component Views

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
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
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Items preview
            VStack(alignment: .leading, spacing: 4) {
                if let items = bundle.items {
                    if let gems = items.gems {
                        Label {
                            Text(verbatim: "\(gems) Gems")
                        } icon: {
                            Image(systemName: "diamond.fill")
                        }
                        .font(.caption)
                    }
                    if let hammers = items.hammers {
                        Label {
                            Text(verbatim: "\(hammers) Hammers")
                        } icon: {
                            Image(systemName: "hammer.fill")
                        }
                        .font(.caption)
                    }
                    if let swaps = items.swaps {
                        Label {
                            Text(verbatim: "\(swaps) Swaps")
                        } icon: {
                            Image(systemName: "arrow.2.squarepath")
                        }
                        .font(.caption)
                    }
                    if let magnets = items.magnets {
                        Label {
                            Text(verbatim: "\(magnets) MegaMerges")
                        } icon: {
                            Image(systemName: "magnet.fill")
                        }
                        .font(.caption)
                    }
                }
                if bundle.perks?.noAds == true {
                    Label("No Ads", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Spacer()
            
            Button {
                Task { await shopStore.purchase(bundle.id) }
            } label: {
                Text(shopStore.formatPrice(bundle.price))
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(shopStore.isPurchased(bundle.id) ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(shopStore.isPurchased(bundle.id) || shopStore.isPurchasing)
        }
        .padding()
        .frame(height: 200)
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
                        .font(.headline)
                    if let tag = gem.tags?.first {
                        Text(tag)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(shopStore.formatPrice(gem.price))
                    .font(.headline)
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
        return Image(systemName: "diamond.fill")
    }
}

struct PerkCard: View {
    let perk: PerkBundle
    @Environment(\.shopStore) private var shopStore
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconForPerk(perk.item))
                .font(.title)
            
            Text(verbatim: "x\(perk.quantity)")
                .font(.headline)
            
            Button {
                Task { await shopStore.purchase(perk.id) }
            } label: {
                Text(shopStore.formatPrice(perk.price))
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .frame(width: 100, height: 120)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func iconForPerk(_ item: String) -> String {
        switch item.lowercased() {
        case "hammer": return "hammer.fill"
        case "swap": return "arrow.2.squarepath"
        case "magnet": return "magnet"
        default: return "star.fill"
        }
    }
}

struct SpecialOfferCard: View {
    let offer: ShopBundle
    @Environment(\.shopStore) private var shopStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(offer.title)
                    .font(.headline)
                
                if let perks = offer.perks {
                    HStack(spacing: 12) {
                        if perks.noAds == true {
                            Label("No Ads", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        if perks.allBeats == true {
                            Label("All Beats", systemImage: "music.note")
                                .font(.caption)
                                .foregroundStyle(.purple)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button {
                Task { await shopStore.purchase(offer.id) }
            } label: {
                Text(shopStore.formatPrice(offer.price))
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct JourneyProgressCard: View {
    @Environment(\.tileJourney) private var journeyStore
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Your Journey")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Highest Tile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AlphaMag.formatTileValue(journeyStore.highestTile))
                        .font(.title2.bold())
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("Next Milestone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AlphaMag.formatTileValue(journeyStore.nextMilestone() ?? 0))
                        .font(.title2.bold())
                        .foregroundStyle(.cyan)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct JourneyTileView: View {
    let label: String
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isUnlocked ? .primary : .tertiary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: 70, height: 70)
        .background(isUnlocked ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
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
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.backgroundColor)
            .foregroundStyle(style.foregroundColor)
            .clipShape(Capsule())
    }
}