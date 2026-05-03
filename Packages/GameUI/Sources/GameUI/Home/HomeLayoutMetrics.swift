import SwiftUI

struct HomeLayoutMetrics {
    struct PlayButtonMetrics {
        let containerHeight: CGFloat
        let buttonHeight: CGFloat
        let maxWidth: CGFloat
        let iconSize: CGFloat
        let fontSize: CGFloat
        let horizontalPadding: CGFloat
        let cornerRadius: CGFloat

        static let fallback = PlayButtonMetrics(
            containerHeight: 104,
            buttonHeight: 88,
            maxWidth: 280,
            iconSize: 34,
            fontSize: 40,
            horizontalPadding: 16,
            cornerRadius: 12
        )
    }

    struct DockMetrics {
        let itemCount: Int
        let horizontalPadding: CGFloat
        let itemSpacing: CGFloat
        let slotWidth: CGFloat
        let buttonSize: CGFloat
        let iconSize: CGFloat
        let badgeFontSize: CGFloat
        let bottomPadding: CGFloat
        let cornerRadius: CGFloat

        var totalWidth: CGFloat {
            guard itemCount > 0 else { return horizontalPadding * 2 }
            return horizontalPadding * 2
                + CGFloat(itemCount) * slotWidth
                + CGFloat(itemCount - 1) * itemSpacing
        }

        var height: CGFloat {
            buttonSize + bottomPadding
        }
    }

    struct RailMetrics {
        let itemCount: Int
        let columnCount: Int
        let buttonSize: CGFloat
        let iconSize: CGFloat
        let labelFontSize: CGFloat
        let labelHeight: CGFloat
        let labelSpacing: CGFloat
        let itemWidth: CGFloat
        let rowSpacing: CGFloat
        let columnSpacing: CGFloat
        let topPadding: CGFloat
        let usesCompactLabels: Bool

        var rowCount: Int {
            guard itemCount > 0 else { return 0 }
            return Int(ceil(Double(itemCount) / Double(columnCount)))
        }

        var itemHeight: CGFloat {
            buttonSize + labelSpacing + labelHeight
        }

        var totalWidth: CGFloat {
            guard columnCount > 0 else { return 0 }
            return CGFloat(columnCount) * itemWidth
                + CGFloat(max(0, columnCount - 1)) * columnSpacing
        }

        var totalHeight: CGFloat {
            guard rowCount > 0 else { return topPadding }
            return topPadding
                + CGFloat(rowCount) * itemHeight
                + CGFloat(max(0, rowCount - 1)) * rowSpacing
        }
    }

    let availableSize: CGSize
    let safeAreaInsets: EdgeInsets
    let leftRailItemCount: Int
    let rightRailItemCount: Int
    let dockItemCount: Int
    let hasRecommendation: Bool
    let contentHorizontalPadding: CGFloat
    let middleHorizontalSpacing: CGFloat
    let play: PlayButtonMetrics
    let dock: DockMetrics
    let estimatedHeaderHeight: CGFloat
    let estimatedBottomOverlayHeight: CGFloat
    let estimatedMiddleHeight: CGFloat

    init(
        availableSize: CGSize,
        safeAreaInsets: EdgeInsets,
        leftRailItemCount: Int,
        rightRailItemCount: Int,
        dockItemCount: Int,
        hasRecommendation: Bool
    ) {
        self.availableSize = availableSize
        self.safeAreaInsets = safeAreaInsets
        self.leftRailItemCount = max(0, leftRailItemCount)
        self.rightRailItemCount = max(0, rightRailItemCount)
        self.dockItemCount = max(1, dockItemCount)
        self.hasRecommendation = hasRecommendation

        let width = max(1, availableSize.width)
        let height = max(1, availableSize.height)
        let compactWidth = width <= 375
        let shortHeight = height <= 700

        contentHorizontalPadding = compactWidth ? 8 : 12
        middleHorizontalSpacing = compactWidth ? 6 : 12

        let dockMetrics = Self.makeDockMetrics(
            availableWidth: width,
            itemCount: max(1, dockItemCount),
            compactWidth: compactWidth
        )
        dock = dockMetrics

        play = Self.makePlayMetrics(
            availableWidth: width,
            compactWidth: compactWidth,
            shortHeight: shortHeight
        )

        let topBarEstimate: CGFloat = compactWidth ? 48 : 54
        let recommendationEstimate: CGFloat = hasRecommendation ? (compactWidth ? 76 : 82) : 0
        estimatedHeaderHeight = topBarEstimate + recommendationEstimate

        estimatedBottomOverlayHeight = play.containerHeight + dockMetrics.height + 8 + safeAreaInsets.bottom

        estimatedMiddleHeight = max(
            140,
            height - safeAreaInsets.top - estimatedHeaderHeight - estimatedBottomOverlayHeight
        )
    }

    func railMetrics(for itemCount: Int, availableHeight: CGFloat? = nil) -> RailMetrics {
        Self.makeRailMetrics(
            availableWidth: availableSize.width,
            availableHeight: max(0, availableHeight ?? estimatedMiddleHeight),
            itemCount: max(0, itemCount)
        )
    }

    func journeyTopInset(measuredHeaderHeight: CGFloat) -> CGFloat {
        safeAreaInsets.top + max(measuredHeaderHeight, estimatedHeaderHeight) + 8
    }

    func journeyBottomInset(measuredPlayHeight: CGFloat, measuredDockHeight: CGFloat) -> CGFloat {
        let measured = measuredPlayHeight + measuredDockHeight + safeAreaInsets.bottom + 8
        return max(measured, estimatedBottomOverlayHeight)
    }

    private static func makePlayMetrics(
        availableWidth: CGFloat,
        compactWidth: Bool,
        shortHeight: Bool
    ) -> PlayButtonMetrics {
        let buttonHeight: CGFloat = shortHeight ? 76 : (compactWidth ? 86 : 98)
        let containerHeight = buttonHeight + (shortHeight ? 12 : 18)
        let horizontalPadding: CGFloat = compactWidth ? 16 : 24
        let maxWidth = min(
            availableWidth - horizontalPadding * 2,
            max(224, availableWidth * (compactWidth ? 0.68 : 0.58))
        )

        return PlayButtonMetrics(
            containerHeight: containerHeight,
            buttonHeight: buttonHeight,
            maxWidth: max(180, maxWidth),
            iconSize: shortHeight ? 30 : (compactWidth ? 34 : 40),
            fontSize: shortHeight ? 34 : (compactWidth ? 40 : 48),
            horizontalPadding: horizontalPadding,
            cornerRadius: compactWidth ? 10 : 12
        )
    }

    private static func makeDockMetrics(
        availableWidth: CGFloat,
        itemCount: Int,
        compactWidth: Bool
    ) -> DockMetrics {
        let count = max(1, itemCount)
        let minimumButtonSize: CGFloat = 44
        let basePadding: CGFloat = compactWidth ? 6 : 12
        let baseSpacing: CGFloat = compactWidth ? 2 : 6
        let minimumButtonsWidth = CGFloat(count) * minimumButtonSize
        let remainingWidth = max(0, availableWidth - minimumButtonsWidth)
        let horizontalPadding = min(basePadding, remainingWidth * 0.25)
        let spacingRoom = max(0, availableWidth - horizontalPadding * 2 - minimumButtonsWidth)
        let itemSpacing = count > 1 ? min(baseSpacing, spacingRoom / CGFloat(count - 1)) : 0
        let slotWidth = floor(
            max(
                minimumButtonSize,
                (availableWidth - horizontalPadding * 2 - itemSpacing * CGFloat(count - 1)) / CGFloat(count)
            )
        )
        let idealButtonSize: CGFloat = compactWidth ? 52 : 62
        let buttonSize = min(idealButtonSize, slotWidth)

        return DockMetrics(
            itemCount: count,
            horizontalPadding: horizontalPadding,
            itemSpacing: itemSpacing,
            slotWidth: slotWidth,
            buttonSize: buttonSize,
            iconSize: min(buttonSize - 8, buttonSize * 0.74),
            badgeFontSize: compactWidth ? 10 : 11,
            bottomPadding: compactWidth ? 10 : 16,
            cornerRadius: compactWidth ? 18 : 22
        )
    }

    private static func makeRailMetrics(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        itemCount: Int
    ) -> RailMetrics {
        guard itemCount > 0 else {
            return RailMetrics(
                itemCount: 0,
                columnCount: 1,
                buttonSize: 44,
                iconSize: 30,
                labelFontSize: 9,
                labelHeight: 10,
                labelSpacing: 1,
                itemWidth: 46,
                rowSpacing: 0,
                columnSpacing: 0,
                topPadding: 0,
                usesCompactLabels: true
            )
        }

        let compactWidth = availableWidth <= 375
        let topPadding: CGFloat = compactWidth ? 4 : 8
        let single = makeRailMetrics(
            availableHeight: availableHeight,
            itemCount: itemCount,
            columnCount: 1,
            topPadding: topPadding,
            compactWidth: compactWidth
        )

        if single.totalHeight <= availableHeight || itemCount <= 3 {
            return single
        }

        return makeRailMetrics(
            availableHeight: availableHeight,
            itemCount: itemCount,
            columnCount: 2,
            topPadding: topPadding,
            compactWidth: true
        )
    }

    private static func makeRailMetrics(
        availableHeight: CGFloat,
        itemCount: Int,
        columnCount: Int,
        topPadding: CGFloat,
        compactWidth: Bool
    ) -> RailMetrics {
        let rows = Int(ceil(Double(itemCount) / Double(columnCount)))
        let minimumButtonSize: CGFloat = 44
        let idealButtonSize: CGFloat = compactWidth || columnCount > 1 ? 48 : 56
        let labelFontSize: CGFloat = compactWidth || columnCount > 1 ? 9 : 11
        let labelHeight: CGFloat = compactWidth || columnCount > 1 ? 10 : 12
        let labelSpacing: CGFloat = compactWidth || columnCount > 1 ? 1 : 2
        let minimumRowSpacing: CGFloat = compactWidth || columnCount > 1 ? 1 : 4
        let preferredRowSpacing: CGFloat = compactWidth || columnCount > 1 ? 4 : 10
        let columnSpacing: CGFloat = columnCount > 1 ? 2 : 0
        let fixedTextHeight = labelHeight + labelSpacing
        let heightAvailableForButtons = availableHeight
            - topPadding
            - CGFloat(max(0, rows - 1)) * minimumRowSpacing
            - CGFloat(rows) * fixedTextHeight
        let fittingButtonSize = floor(heightAvailableForButtons / CGFloat(max(1, rows)))
        let buttonSize = min(idealButtonSize, max(minimumButtonSize, fittingButtonSize))
        let itemHeight = buttonSize + fixedTextHeight
        let remaining = availableHeight - topPadding - CGFloat(rows) * itemHeight
        let rowSpacing: CGFloat
        if rows > 1 {
            rowSpacing = min(preferredRowSpacing, max(minimumRowSpacing, remaining / CGFloat(rows - 1)))
        } else {
            rowSpacing = 0
        }
        let itemWidth = buttonSize + (columnCount > 1 ? 2 : 10)

        return RailMetrics(
            itemCount: itemCount,
            columnCount: columnCount,
            buttonSize: buttonSize,
            iconSize: min(buttonSize - 8, buttonSize * 0.7),
            labelFontSize: labelFontSize,
            labelHeight: labelHeight,
            labelSpacing: labelSpacing,
            itemWidth: itemWidth,
            rowSpacing: rowSpacing,
            columnSpacing: columnSpacing,
            topPadding: topPadding,
            usesCompactLabels: compactWidth || columnCount > 1
        )
    }
}
