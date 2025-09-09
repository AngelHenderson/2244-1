import SwiftUI
import GameKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class GameCenterManager {
    public static let shared = GameCenterManager()
    private init() {}
    
    public func configureAccessPoint(active: Bool = true,
                                     location: GKAccessPoint.Location = .topLeading) {
        GKAccessPoint.shared.isActive = active
        GKAccessPoint.shared.location = location
    }
    
    #if canImport(UIKit)
    public func authenticateIfNeeded(presentingRoot rootProvider: @escaping () -> UIViewController?) {
        let local = GKLocalPlayer.local
        guard !local.isAuthenticated else { return }
        local.authenticateHandler = { vc, error in
            if let vc = vc, let root = rootProvider() {
                root.present(vc, animated: true, completion: nil)
            } else if let error = error {
                #if DEBUG
                print("Game Center auth error:", error)
                #endif
            }
        }
    }
    #endif
    
    public func loadExistingAchievements() async -> [GKAchievement] {
        await withCheckedContinuation { cont in
            GKAchievement.loadAchievements { result, _ in
                cont.resume(returning: result ?? [])
            }
        }
    }
    
    public func reportUnlock(gcIdentifier: String, showsBanner: Bool = true) async {
        let ach = GKAchievement(identifier: gcIdentifier)
        ach.percentComplete = 100.0
        ach.showsCompletionBanner = showsBanner
        await withCheckedContinuation { cont in
            GKAchievement.report([ach]) { _ in cont.resume(returning: ()) }
        }
    }
    
    public func presentDashboard() {
        #if canImport(UIKit)
        guard let root = Self.topMostViewController() else { return }
        let vc = GKGameCenterViewController(state: .achievements)
        vc.gameCenterDelegate = root as? any GKGameCenterControllerDelegate
        root.present(vc, animated: true)
        #endif
    }
    
    #if canImport(UIKit)
    private static func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow })
        else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #endif
}