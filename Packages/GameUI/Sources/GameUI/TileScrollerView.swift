import SwiftUI
import GameCore
import GameApp

public struct TileScrollerView: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.tileJourney) private var journey
    @Environment(\.homeActions) private var actions
    @State private var focusedTileID: Int? = nil
    @State private var showAnimation = false
    @State private var scrollPosition = ScrollPosition(idType: Int.self)
    
    // Insets from overlays above/below (header, play button, dock) so the
    // "visual center" matches the unobstructed area rather than the screen center.
    private let topInset: CGFloat
    private let bottomInset: CGFloat
    
    private var currentHighestTile: Int {
        max(2, gameStore.state.highestTile)
    }
    
    private let itemSpacing: CGFloat = 24
    private let tileSize: CGFloat = 140
    
    // Build the full journey, then reverse for an upward-growing panel (2 near bottom, Infinity toward top).
    private var tiles: [(id: Int, tile: Tile)] {
        let modelsAscending = JourneyTileGenerator.generateFullJourney()
        let models = modelsAscending.reversed() // visual goes up
        return Array(models.enumerated().map { ($0.offset, $0.element) })
    }
    
    private var highestUnlockedIndex: Int? {
        let highestValue = max(2, gameStore.state.highestTile)
        return tiles.firstIndex { item in
            !item.tile.isInfinity && item.tile.value == highestValue
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
                    ForEach(tiles, id: \.id) { item in
                        TileRowItem(
                            tile: item.tile,
                            isLocked: isLocked(item.tile),
                            isCurrentHighest: item.tile.value == currentHighestTile && !item.tile.isInfinity,
                            tileSize: tileSize
                        )
                        .id(item.id)
                        .scrollTransition(.interactive, axis: .vertical) { view, phase in
                            view
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.92)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 24)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition($scrollPosition, anchor: .center)
            .defaultScrollAnchor(.center)
            .contentMargins(.vertical, tileSize / 2 + itemSpacing, for: .scrollContent)
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
        return tile.value > gameStore.state.highestTile
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
    
    private var showCrown: Bool {
        !tile.isInfinity
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                TileView(
                    tile: tile,
                    isSelected: false,
                    isValid: true,
                    size: tileSize,
                    useLegacyTypography: true   // Preserve the previous journey look
                )
                .saturation(isLocked ? 0.0 : 1.0)
                .overlay(
                    isCurrentHighest ?
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
                    : nil
                )
                .animation(.snappy(duration: 0.25), value: isLocked)
                .animation(.snappy(duration: 0.25), value: isCurrentHighest)
                
                // Crown overlay to match design
                if showCrown {
                    VStack {
                        Image("crownBadge")
                            .resizable()
                            .scaledToFit()
                            .frame(height: tileSize * 0.28)
                            .offset(y: -tileSize * 0.62)
                    }
                }
            }
            
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
            } else if isCurrentHighest {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text("Current")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 80)
    }
}

#Preview {
    TileScrollerView()
        .environment(\.gameStore, GameStore())
        .environment(\.tileJourney, JourneyKit.Store(config: .init(minPower: 20, maxPower: 25)))
}
