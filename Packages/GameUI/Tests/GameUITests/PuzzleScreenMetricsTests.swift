import SwiftUI
import Testing
@testable import GameUI

struct PuzzleScreenMetricsTests {
    @Test
    func iPhoneSEResolvesToCompactCompressed() {
        let metrics = PuzzleScreenMetrics(
            container: CGSize(width: 375, height: 667),
            safeArea: EdgeInsets(),
            rows: 8,
            columns: 5
        )

        #expect(metrics.placement == .compactCompressed)
        #expect(metrics.compression == .collapsed)
        #expect(metrics.shouldCollapseTools)
    }

    @Test
    func iPhoneProMaxPortraitResolvesToExpandedCompact() {
        let metrics = PuzzleScreenMetrics(
            container: CGSize(width: 430, height: 932),
            safeArea: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0),
            rows: 8,
            columns: 5
        )

        #expect(metrics.placement == .compact)
        #expect(metrics.compression == .expanded)
        #expect(!metrics.shouldCollapseTools)
    }

    @Test
    func iPadPortraitResolvesToCentered() {
        let metrics = PuzzleScreenMetrics(
            container: CGSize(width: 820, height: 1180),
            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
            rows: 8,
            columns: 5
        )

        #expect(metrics.placement == .centered)
        #expect(metrics.maxTileSize == PuzzleScreenMetrics.centeredTabletMaxTileSize)
        #expect(metrics.boardSize.width <= PuzzleScreenMetrics.centeredMaxBoardWidth)
    }

    @Test
    func iPadLandscapeResolvesToSidebar() {
        let metrics = PuzzleScreenMetrics(
            container: CGSize(width: 1180, height: 820),
            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
            rows: 8,
            columns: 5
        )

        #expect(metrics.placement == .sidebar)
        #expect(metrics.sidePanelWidth > 0)
        #expect(metrics.maxTileSize == PuzzleScreenMetrics.sidebarTabletMaxTileSize)
    }

    @Test
    func SplitViewWidthFollowsGeometry() {
        let metrics = PuzzleScreenMetrics(
            container: CGSize(width: 650, height: 900),
            safeArea: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
            rows: 8,
            columns: 5
        )

        #expect(metrics.placement == .compact)
    }
}

struct PuzzleBoardSizingTests {
    @Test
    func tileSizeIncludesOuterAndInnerSpacing() {
        let tileSize = PuzzleBoardSizing.tileSize(
            availableWidth: 390,
            availableHeight: 700,
            rows: 8,
            columns: 5,
            spacing: 10
        )

        #expect(tileSize == 66)
        #expect(PuzzleBoardSizing.boardSize(tileSize: tileSize, rows: 8, columns: 5, spacing: 10).width == 390)
    }

    @Test
    func tileSizeRespectsMaxCap() {
        let tileSize = PuzzleBoardSizing.tileSize(
            availableWidth: 1_000,
            availableHeight: 1_000,
            rows: 8,
            columns: 5,
            spacing: 10,
            maxTileSize: 76
        )

        #expect(tileSize == 76)
    }

    @Test
    func boardSizeFitsAvailableSpace() {
        let metrics = PuzzleScreenMetrics(
            container: CGSize(width: 430, height: 932),
            safeArea: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0),
            rows: 8,
            columns: 5
        )

        #expect(metrics.boardSize.width <= 430 - metrics.margin * 2)
        #expect(metrics.boardSize.height <= 932 - 47 - 34)
    }
}
