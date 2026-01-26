import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class HapticsService: Sendable {
    #if canImport(UIKit)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    #endif
    
    public init() {
        #if canImport(UIKit)
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selection.prepare()
        notification.prepare()
        #endif
    }
    
    public func lightImpact() {
        #if canImport(UIKit)
        impactLight.impactOccurred()
        #endif
    }
    
    public func mediumImpact() {
        #if canImport(UIKit)
        impactMedium.impactOccurred()
        #endif
    }
    
    public func heavyImpact() {
        #if canImport(UIKit)
        impactHeavy.impactOccurred()
        #endif
    }
    
    public func selectionChanged() {
        #if canImport(UIKit)
        selection.selectionChanged()
        #endif
    }
    
    public func success() {
        #if canImport(UIKit)
        notification.notificationOccurred(.success)
        #endif
    }
    
    public func warning() {
        #if canImport(UIKit)
        notification.notificationOccurred(.warning)
        #endif
    }
    
    public func error() {
        #if canImport(UIKit)
        notification.notificationOccurred(.error)
        #endif
    }
}
