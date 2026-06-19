import SwiftUI

struct SideRailButton: View {
    let systemImage: String?
    let customImage: String?
    let title: String
    let metrics: HomeLayoutMetrics.RailMetrics
    var badge: Bool = false
    var badgeCount: Int? = nil  // If set, shows count instead of dot
    var locked: Bool = false
    var banned: Bool = false
    var specialLabel: String? = nil
    var specialLabelInside: Bool = false  // If true, show specialLabel inside the button
    var countdownDeadline: Date? = nil
    var onLockedTap: (() -> Void)? = nil
    var onBannedTap: (() -> Void)? = nil
    var action: () -> Void
    
    @Environment(\.currentBackgroundTheme) private var backgroundTheme

    var body: some View {
        VStack(spacing: metrics.labelSpacing) {
            Button(action: {
                if banned {
                    onBannedTap?()
                } else if locked {
                    onLockedTap?()
                } else {
                    action()
                }
            }) {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .bottom) {
                        ZStack {
                            boundedIcon
                        }
                        .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                        .overlay {
                            if banned {
                                ZStack {
                                    Color.black.opacity(0.4)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Image(systemName: "exclamationmark.octagon.fill")
                                        .font(.system(size: max(18, metrics.buttonSize * 0.38)))
                                        .foregroundStyle(Color(red: 0.85, green: 0.15, blue: 0.15))
                                }
                            } else if locked {
                                ZStack {
                                    Image("lockpic")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: max(18, metrics.buttonSize * 0.42), height: max(18, metrics.buttonSize * 0.42))
                                }
                            }
                        }

                        if specialLabelInside, !banned, !locked, let specialLabel = specialLabel, !specialLabel.isEmpty {
                            HStack(spacing: 2) {
                                Image("gem")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: max(8, metrics.buttonSize * 0.18), height: max(8, metrics.buttonSize * 0.18))
                                Text(specialLabel)
                                    .font(.avenirNext(size: max(8, metrics.labelFontSize), weight: .heavy))
                                    .foregroundStyle(backgroundTheme.textColor)
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(.black.opacity(0.28), in: Capsule())
                            .padding(.bottom, 2)
                        }
                    }
                    .frame(width: metrics.buttonSize, height: metrics.buttonSize)
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .glassEffectCompat(cornerRadius: cornerRadius)

                    if !locked {
                        if let count = badgeCount, count > 0 {
                            Text("\(count)")
                                .font(.avenirNext(size: max(8, metrics.labelFontSize), weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: max(14, metrics.buttonSize * 0.32), minHeight: max(14, metrics.buttonSize * 0.32))
                                .background(Circle().fill(.red))
                                .offset(x: 4, y: -4)
                                .accessibilityHidden(true)
                        } else if badge {
                            Circle()
                                .fill(.red)
                                .frame(width: max(8, metrics.buttonSize * 0.18), height: max(8, metrics.buttonSize * 0.18))
                                .offset(x: 4, y: -4)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: metrics.buttonSize, height: metrics.buttonSize)
            .accessibilityLabel("\(title)\(locked ? ", locked" : "")")

            if let countdownDeadline {
                CountdownView(deadline: countdownDeadline, fontSize: metrics.labelFontSize)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: metrics.itemWidth, height: metrics.labelHeight)
            } else if !specialLabelInside, let specialLabel = specialLabel, !specialLabel.isEmpty {
                Text(specialLabel)
                    .font(.avenirNext(size: metrics.labelFontSize, weight: .heavy))
                    .foregroundStyle(backgroundTheme.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: metrics.itemWidth, height: metrics.labelHeight)
            } else if !title.isEmpty {
                Text(visualTitle)
                    .font(.avenirNext(size: metrics.labelFontSize, weight: .heavy))
                    .foregroundStyle(backgroundTheme.textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: metrics.itemWidth, height: metrics.labelHeight)
            }
        }
        .frame(width: metrics.itemWidth, height: metrics.itemHeight)
    }

    @ViewBuilder
    private var boundedIcon: some View {
        if let systemImage = systemImage {
            Image(systemName: systemImage)
                .font(.system(size: metrics.iconSize, weight: .semibold))
        } else if let customImage = customImage {
            Image(customImage)
                .resizable()
                .scaledToFill()
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .clipShape(RoundedRectangle(cornerRadius: max(6, metrics.buttonSize * 0.16)))
                .accessibilityHidden(true)
        } else {
            EmptyView()
        }
    }

    private var visualTitle: String {
        guard metrics.usesCompactLabels else { return title }
        switch title {
        case "FREE SPIN": return "SPIN"
        case "BEST OFFER": return "OFFER"
        case "CHALLENGE": return "CHAL."
        case "PRACTICE": return "PRAC."
        default: return title
        }
    }

    private var cornerRadius: CGFloat {
        max(10, metrics.buttonSize * 0.22)
    }
}
