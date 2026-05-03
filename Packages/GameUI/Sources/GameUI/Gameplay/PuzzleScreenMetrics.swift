import SwiftUI

enum PuzzleScreenPlacement: Equatable {
    case compact
    case compactCompressed
    case centered
    case sidebar
}

enum PuzzleChromeCompression: Equatable {
    case expanded
    case compact
    case collapsed
}

struct PuzzleScreenMetrics: Equatable {
    static let phoneMaxTileSize: CGFloat = 76
    static let centeredTabletMaxTileSize: CGFloat = 84
    static let sidebarTabletMaxTileSize: CGFloat = 88
    static let centeredMaxBoardWidth: CGFloat = 620
    static let sidebarMaxBoardWidth: CGFloat = 680
    static let sidebarGap: CGFloat = 24
    static let minimumExpandedToolTileSize: CGFloat = 52

    let placement: PuzzleScreenPlacement
    let compression: PuzzleChromeCompression
    let margin: CGFloat
    let sectionSpacing: CGFloat
    let gridSpacing: CGFloat
    let tileSize: CGFloat
    let maxTileSize: CGFloat
    let boardSize: CGSize
    let hudHeight: CGFloat
    let objectiveHeight: CGFloat
    let toolTrayHeight: CGFloat
    let sidePanelWidth: CGFloat
    let shouldCollapseTools: Bool

    init(container: CGSize, safeArea: EdgeInsets, rows: Int, columns: Int) {
        let usableWidth = max(1, container.width)
        let usableHeight = max(1, container.height - safeArea.top - safeArea.bottom)
        let isRegularWidth = usableWidth >= 700
        let usesSidebar = usableWidth >= 900 && usableHeight >= 620

        let compression: PuzzleChromeCompression
        if usableHeight >= 760 {
            compression = .expanded
        } else if usableHeight >= 680 {
            compression = .compact
        } else {
            compression = .collapsed
        }

        let placement: PuzzleScreenPlacement
        if usesSidebar {
            placement = .sidebar
        } else if isRegularWidth {
            placement = .centered
        } else if compression == .collapsed {
            placement = .compactCompressed
        } else {
            placement = .compact
        }

        let marginCap: CGFloat = isRegularWidth ? 32 : 24
        let margin = min(max(usableWidth * 0.045, 16), marginCap)
        let sectionSpacing: CGFloat
        let gridSpacing: CGFloat
        switch compression {
        case .expanded:
            sectionSpacing = 12
            gridSpacing = 10
        case .compact:
            sectionSpacing = 10
            gridSpacing = 9
        case .collapsed:
            sectionSpacing = 8
            gridSpacing = 7
        }

        let hudHeight: CGFloat = 0
        let objectiveHeight: CGFloat
        switch (usesSidebar, compression) {
        case (true, _):
            objectiveHeight = 0
        case (_, .expanded):
            objectiveHeight = 42
        case (_, .compact):
            objectiveHeight = 36
        case (_, .collapsed):
            objectiveHeight = 30
        }

        let sidePanelWidth = usesSidebar ? min(max(usableWidth * 0.27, 260), 340) : 0
        let maxTileSize = usesSidebar
            ? Self.sidebarTabletMaxTileSize
            : (isRegularWidth ? Self.centeredTabletMaxTileSize : Self.phoneMaxTileSize)

        func tileLength(toolHeight: CGFloat) -> CGFloat {
            let widthBudget: CGFloat
            if usesSidebar {
                let rawWidth = usableWidth - sidePanelWidth - margin * 2 - Self.sidebarGap
                widthBudget = min(rawWidth, Self.sidebarMaxBoardWidth)
            } else if isRegularWidth {
                widthBudget = min(usableWidth - margin * 2, Self.centeredMaxBoardWidth)
            } else {
                widthBudget = usableWidth - margin * 2
            }

            let heightBudget: CGFloat
            if usesSidebar {
                heightBudget = usableHeight - margin * 2
            } else {
                heightBudget = usableHeight
                    - margin * 2
                    - objectiveHeight
                    - toolHeight
                    - sectionSpacing * 2
            }

            return PuzzleBoardSizing.tileSize(
                availableWidth: widthBudget,
                availableHeight: heightBudget,
                rows: rows,
                columns: columns,
                spacing: gridSpacing,
                maxTileSize: maxTileSize
            )
        }

        let expandedToolsHeight: CGFloat = usesSidebar ? 0 : (compression == .expanded ? 64 : 56)
        let compactToolsHeight: CGFloat = usesSidebar ? 0 : 48
        let initialToolsHeight = compression == .collapsed ? compactToolsHeight : expandedToolsHeight
        let initialTileSize = tileLength(toolHeight: initialToolsHeight)
        let shouldCollapseTools = !usesSidebar
            && (compression == .collapsed || initialTileSize < Self.minimumExpandedToolTileSize)
        let toolTrayHeight = usesSidebar ? 0 : (shouldCollapseTools ? compactToolsHeight : expandedToolsHeight)
        let tileSize = floor(max(1, tileLength(toolHeight: toolTrayHeight)))

        self.placement = placement
        self.compression = compression
        self.margin = margin
        self.sectionSpacing = sectionSpacing
        self.gridSpacing = gridSpacing
        self.tileSize = tileSize
        self.maxTileSize = maxTileSize
        self.boardSize = PuzzleBoardSizing.boardSize(
            tileSize: tileSize,
            rows: rows,
            columns: columns,
            spacing: gridSpacing
        )
        self.hudHeight = hudHeight
        self.objectiveHeight = objectiveHeight
        self.toolTrayHeight = toolTrayHeight
        self.sidePanelWidth = sidePanelWidth
        self.shouldCollapseTools = shouldCollapseTools
    }
}

enum PuzzleBoardSizing {
    static func tileSize(
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        rows: Int,
        columns: Int,
        spacing: CGFloat,
        maxTileSize: CGFloat? = nil
    ) -> CGFloat {
        guard availableWidth.isFinite,
              availableHeight.isFinite,
              availableWidth > 0,
              availableHeight > 0 else {
            return 0
        }

        let rowCount = max(1, rows)
        let columnCount = max(1, columns)
        let horizontalSpacing = spacing * CGFloat(columnCount + 1)
        let verticalSpacing = spacing * CGFloat(rowCount + 1)
        let width = max(0, availableWidth - horizontalSpacing) / CGFloat(columnCount)
        let height = max(0, availableHeight - verticalSpacing) / CGFloat(rowCount)
        let uncapped = min(width, height)
        let capped = min(uncapped, maxTileSize ?? uncapped)
        return capped.isFinite ? max(0, capped) : 0
    }

    static func boardSize(tileSize: CGFloat, rows: Int, columns: Int, spacing: CGFloat) -> CGSize {
        let rowCount = max(1, rows)
        let columnCount = max(1, columns)
        return CGSize(
            width: CGFloat(columnCount) * tileSize + spacing * CGFloat(columnCount + 1),
            height: CGFloat(rowCount) * tileSize + spacing * CGFloat(rowCount + 1)
        )
    }
}
