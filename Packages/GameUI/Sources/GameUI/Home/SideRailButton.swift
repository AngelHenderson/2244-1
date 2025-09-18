import SwiftUI

struct SideRailButton: View {
    let systemImage: String?
    let customImage: String?
    let title: String
    var badge: Bool = false
    var locked: Bool = false
    var specialLabel: String? = nil
    var action: () -> Void

    var body: some View {
        VStack{
            Button(action: { if !locked { action() } }) {
                VStack(spacing: 6) {
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            if let systemImage = systemImage {
                                Image(systemName: systemImage)
                                    .font(.system(size: 24, weight: .semibold))
                            } else if let customImage = customImage {
                                Image(customImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 56)
                                    .accessibilityHidden(true)
                            }

                            if let specialLabel = specialLabel {
                                Text(specialLabel)
                                    .font(.caption.bold())
                            }
                        }
                        .frame(width: 56, height: 56)
                        .overlay {
                            if locked {
                                ZStack {
                                    Image("lockpic")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }

                        if badge && !locked {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 6, y: -6)
                                .accessibilityHidden(true)
                        }
                    }

                }
            }
            .modifier(GlassButtonCompat())
            .disabled(locked)
            .accessibilityLabel("\(title)\(locked ? ", locked" : "")")

            Text(title)
                .font(.caption2)
                .fontWeight(.heavy)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }

    }
}

private struct GlassButtonCompat: ViewModifier {
    @Environment(\.gameStore) private var gameStore
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .tint(dynamicGlassTint)
        } else {
            content.buttonStyle(.plain)
        }
    }
    
    /// Dynamically compute glass tint based on current board state
    /// Dynamically compute glass tint based on current board state
    private var dynamicGlassTint: Color {
        // Get tiles from the board
        let boardTiles = gameStore.state.board.tiles.compactMap { $0 }
        
        if boardTiles.isEmpty {
            return .teal // Default fallback
        }
        
        // Find the highest tile value
        let highestValue = boardTiles.map { $0.value }.max() ?? 128
        
        // Use Theme system to get the color for the highest tile
        return Theme.color(for: highestValue)
    }
}
