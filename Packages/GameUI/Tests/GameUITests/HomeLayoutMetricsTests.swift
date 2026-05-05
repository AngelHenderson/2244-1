import SwiftUI
import Testing
@testable import GameUI

@Suite("HomeLayoutMetrics")
struct HomeLayoutMetricsTests {
    @Test
    func compactPhoneWithMaxControlsFits() {
        let metrics = HomeLayoutMetrics(
            availableSize: CGSize(width: 320, height: 568),
            safeAreaInsets: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0),
            leftRailItemCount: 6,
            rightRailItemCount: 6,
            dockItemCount: 6,
            hasRecommendation: true
        )

        assertContained(metrics)
        #expect(metrics.railMetrics(for: 6).columnCount == 2)
    }

    @Test
    func iPhone16PortraitWithMaxControlsFits() {
        let metrics = HomeLayoutMetrics(
            availableSize: CGSize(width: 393, height: 852),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            leftRailItemCount: 6,
            rightRailItemCount: 6,
            dockItemCount: 6,
            hasRecommendation: true
        )

        assertContained(metrics)
    }

    @Test
    func tallPhoneWithMaxControlsFits() {
        let metrics = HomeLayoutMetrics(
            availableSize: CGSize(width: 430, height: 932),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0),
            leftRailItemCount: 6,
            rightRailItemCount: 6,
            dockItemCount: 6,
            hasRecommendation: true
        )

        assertContained(metrics)
    }

    @Test
    func iPadPortraitWithMaxControlsFits() {
        let metrics = HomeLayoutMetrics(
            availableSize: CGSize(width: 768, height: 1024),
            safeAreaInsets: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0),
            leftRailItemCount: 6,
            rightRailItemCount: 6,
            dockItemCount: 6,
            hasRecommendation: true
        )

        assertContained(metrics)
    }

    private func assertContained(_ metrics: HomeLayoutMetrics) {
        let leftRail = metrics.railMetrics(for: metrics.leftRailItemCount)
        let rightRail = metrics.railMetrics(for: metrics.rightRailItemCount)
        let railWidth = leftRail.totalWidth
            + rightRail.totalWidth
            + metrics.middleHorizontalSpacing
            + metrics.contentHorizontalPadding * 2

        #expect(metrics.dock.totalWidth <= metrics.availableSize.width + 0.5)
        #expect(railWidth <= metrics.availableSize.width + 0.5)
        #expect(leftRail.totalHeight <= metrics.estimatedMiddleHeight + 0.5)
        #expect(rightRail.totalHeight <= metrics.estimatedMiddleHeight + 0.5)
        #expect(metrics.dock.buttonSize >= 44)
        #expect(leftRail.buttonSize >= 44)
        #expect(rightRail.buttonSize >= 44)
        #expect(metrics.play.buttonHeight >= 44)
    }
}
