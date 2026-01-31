import SwiftUI
import GameCore
import GameApp
#if canImport(UIKit)
import UIKit
#endif

public struct TileScrollerView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.tileJourney) private var journey
    @Environment(\.homeActions) private var actions
    @State private var focusedTileID: Int? = nil
    @AppStorage("useCurvedTrail") private var showCurvedTrail: Bool = false
    @State private var showAnimation = false
    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    
    // Insets from overlays above/below (header, play button, dock) so the
    // "visual center" matches the unobstructed area rather than the screen center.
    private let topInset: CGFloat
    private let bottomInset: CGFloat
    
    private var highestTileStep: Int {
        max(0, gameStore.state.highestTileStep)
    }
    
    private let itemSpacing: CGFloat = 0 // Spacing is now handled by the trails
    private let tileSize: CGFloat = 140
    
    // Build the full journey, then reverse for an upward-growing panel (2 near bottom, Infinity toward top).
    private var tiles: [(id: Int, tile: Tile)] {
        // Use GameCore's generator which handles values beyond Int.max (up to 873bz)
        let modelsAscending = GameCore.JourneyTileGenerator.generateFullJourney()
        let models = modelsAscending.reversed() // visual goes up
        return Array(models.enumerated().map { ($0.offset, $0.element) })
    }
    
    private var highestUnlockedIndex: Int? {
        return tiles.firstIndex { item in
            guard !item.tile.isInfinity else { return false }
            return tileStep(for: item.tile) == highestTileStep
        }
    }
    
    public init(topInset: CGFloat = 0, bottomInset: CGFloat = 0) {
        self.topInset = topInset
        self.bottomInset = bottomInset
    }
    
    public var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: itemSpacing) {
                    ForEach(Array(tiles.enumerated()), id: \.element.id) { index, item in
                        TileRowItem(
                            tile: item.tile,
                            isLocked: isLocked(item.tile),
                            isCurrentHighest: !item.tile.isInfinity && tileStep(for: item.tile) == highestTileStep,
                            tileSize: tileSize,
                            // Force classic theme for journey to lock legacy color mapping
                            theme: ThemeRegistry.Default.descriptor(for: "classic")
                        )
                        .id(item.id)
                        .scrollTransition(.interactive, axis: .vertical) { view, phase in
                            view
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.92)
                        }
                        
                        // Connector Trail - only add if not the last item
                        if index < tiles.count - 1 {
                            Group {
                                if showCurvedTrail {
                                    CurvedTrailView(color: .cyan.opacity(0.7), lineWidth: 5)
                                } else {
                                    DottedTrail(dotCount: 5, dotSize: 8, dotSpacing: 10, color: .white.opacity(0.5))
                                }
                            }
                            .frame(height: 80)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 24)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition($scrollPosition, anchor: .center)
            .defaultScrollAnchor(.center)
            .contentMargins(.vertical, tileSize / 2 + 24, for: .scrollContent)
            .background(Color.black.opacity(0.001))
            .safeAreaPadding(.top, topInset)
            .safeAreaPadding(.bottom, bottomInset)
            .task {
                await setInitialScrollPosition()
            }
            .onAppear {
                if let currentIndex = highestUnlockedIndex {
                    scrollPosition.scrollTo(id: currentIndex, anchor: .center)
                    focusedTileID = currentIndex
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    showAnimation = true
                }
            }
            .onChange(of: gameStore.state.highestTile) { _, newValue in
                if let newIndex = tiles.firstIndex(where: { !$0.tile.isInfinity && $0.tile.value == newValue }) {
                    withAnimation(.snappy(duration: 0.3)) {
                        scrollPosition.scrollTo(id: newIndex, anchor: .center)
                        focusedTileID = newIndex
                    }
                }
            }
            .onChange(of: topInset) { _, _ in recenterToCurrent() }
            .onChange(of: bottomInset) { _, _ in recenterToCurrent() }
            
            // Navigation arrows
            VStack {
                // Up arrow (to 873bz)
                Button(action: {
                    scrollToTop()
                }) {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.3), in: Circle())
                        .shadow(radius: 4)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Down arrow (to 2)
                Button(action: {
                    scrollToBottom()
                }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.3), in: Circle())
                        .shadow(radius: 4)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
        }
    }
    
    private func isLocked(_ tile: Tile) -> Bool {
        if tile.isInfinity { return true }
        return tileStep(for: tile) > highestTileStep
    }
    
    @MainActor
    private func setInitialScrollPosition() async {
        if let currentIndex = highestUnlockedIndex {
            scrollPosition.scrollTo(id: currentIndex, anchor: .center)
            focusedTileID = currentIndex
            try? await Task.sleep(nanoseconds: 100_000_000)
            scrollPosition.scrollTo(id: currentIndex, anchor: .center)
        } else {
            if let firstTileIndex = tiles.firstIndex(where: { !$0.tile.isInfinity }) {
                scrollPosition.scrollTo(id: firstTileIndex, anchor: .center)
                focusedTileID = firstTileIndex
            }
        }
    }
    
    @MainActor
    private func recenterToCurrent() {
        if let currentIndex = focusedTileID ?? highestUnlockedIndex {
            scrollPosition.scrollTo(id: currentIndex, anchor: .center)
        }
    }
    
    private func tileStep(for tile: Tile) -> Int {
        if case .highValue(let step) = tile.type {
            return step
        }
        return TileStepLabelFormatter.stepForValue(tile.value, start: 2) ?? 0
    }
    
    @MainActor
    private func scrollToTop() {
        // Scroll to 873bz tile (index 1, since index 0 is infinity)
        let topIndex = 1
        withAnimation(.snappy(duration: 0.5)) {
            scrollPosition.scrollTo(id: topIndex, anchor: .center)
            focusedTileID = topIndex
        }
    }
    
    @MainActor
    private func scrollToBottom() {
        // Scroll to 2 tile (last index)
        let bottomIndex = tiles.count - 1
        withAnimation(.snappy(duration: 0.5)) {
            scrollPosition.scrollTo(id: bottomIndex, anchor: .center)
            focusedTileID = bottomIndex
        }
    }
}

private struct TileRowItem: View {
    let tile: Tile
    let isLocked: Bool
    let isCurrentHighest: Bool
    let tileSize: CGFloat
    let theme: ThemeDescriptor?
    
    private var hasLabel: Bool {
        tile.isInfinity || isCurrentHighest
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TileView(
                tile: tile,
                isSelected: false,
                isValid: true,
                size: tileSize,
                theme: theme
            )
            .saturation(isLocked ? 0.0 : 1.0)
            .conditionalOverlay(isCurrentHighest) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 8)
            }
            .overlay(alignment: .bottom) {
                // Star and "Current" label inside the tile
                if isCurrentHighest {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.4), in: Capsule())
                    .padding(.bottom, 8)
                }
            }
            .animation(.snappy(duration: 0.25), value: isLocked)
            .animation(.snappy(duration: 0.25), value: isCurrentHighest)
            
            // Only show label section with spacing when there's actually a label
            if tile.isInfinity {
                Text("Ultimate Goal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 12)
            }
            // No EmptyView needed - VStack with spacing 0 won't add extra space
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 80)
    }
}

private extension View {
    @ViewBuilder
    func conditionalOverlay<Overlay: View>(_ condition: Bool, @ViewBuilder _ overlay: () -> Overlay) -> some View {
        if condition {
            self.overlay(overlay())
        } else {
            self
        }
    }
}

#Preview {
    TileScrollerView()
        .environment(\.gameStore, GameStore())
        .environment(\.tileJourney, JourneyKit.Store(config: .init(minPower: 20, maxPower: 25)))
}
