import SwiftUI

struct SideRailButton: View {
    let systemImage: String?
    let customImage: String?
    let title: String
    var badge: Bool = false
    var badgeCount: Int? = nil  // If set, shows count instead of dot
    var locked: Bool = false
    var banned: Bool = false
    var specialLabel: String? = nil
    var specialLabelInside: Bool = false  // If true, show specialLabel inside the button
    var onLockedTap: (() -> Void)? = nil
    var onBannedTap: (() -> Void)? = nil
    var action: () -> Void
    
    @Environment(\.currentBackgroundTheme) private var backgroundTheme

    var body: some View {
        VStack{
            Button(action: {
                if banned {
                    onBannedTap?()
                } else if locked {
                    onLockedTap?()
                } else {
                    action()
                }
            }) {
                VStack(spacing: 4) {
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            if let systemImage = systemImage {
                                Image(systemName: systemImage)
                                    .font(.system(size: 24, weight: .semibold))
                            } else if let customImage = customImage {
                                Image(customImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .overlay {
                            if banned {
                                ZStack {
                                    Color.black.opacity(0.4)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Image(systemName: "exclamationmark.octagon.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15))
                                }
                            } else if locked {
                                ZStack {
                                    Image("lockpic")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }

                        if !locked {
                            if let count = badgeCount, count > 0 {
                                // Show count badge
                                Text("\(count)")
                                    .font(.avenirNext(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Circle().fill(.red))
                                    .offset(x: 6, y: -6)
                                    .accessibilityHidden(true)
                            } else if badge {
                                // Show simple dot badge
                                Circle()
                                    .fill(.red)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 6, y: -6)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    
                    // Special label inside the button (e.g., gem reward for ad button)
                    if specialLabelInside, let specialLabel = specialLabel, !specialLabel.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.cyan)
                            Text(specialLabel)
                                .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                                .foregroundStyle(backgroundTheme.textColor)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }

                }
            }
            .modifier(GlassButtonCompat())
            .accessibilityLabel("\(title)\(locked ? ", locked" : "")")

            // Display title or specialLabel below the button with consistent styling
            if !specialLabelInside, let specialLabel = specialLabel, !specialLabel.isEmpty {
                Text(specialLabel)
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                    .foregroundStyle(backgroundTheme.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if !title.isEmpty {
                Text(title)
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .heavy))
                    .foregroundStyle(backgroundTheme.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }

    }
}

private struct GlassButtonCompat: ViewModifier {
    @Environment(\.gameStore) private var gameStore
    
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
    
}
