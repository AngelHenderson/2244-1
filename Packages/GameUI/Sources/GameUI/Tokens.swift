import SwiftUI

/// Design tokens used across GameUI v2 for consistent sizing and spacing.
enum Tokens {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    enum Radius {
        static let chip: CGFloat = 10
        static let tileRounded: CGFloat = 12
        static let tileRounded3D: CGFloat = 24
        static let frame: CGFloat = 20
        static let pill: CGFloat = 12
    }
    
    enum Size {
        static let toolbarButton: CGFloat = 56
        static let chip: CGFloat = 36
        static let chipCurrent: CGFloat = 44
        static let reserve: CGFloat = 76
        static let pathWidth: CGFloat = 6
        static let tileMax: CGFloat = 80
    }
    
    enum Shadow {
        static let board = Color.black.opacity(0.5)
        static let boardRadius: CGFloat = 18
        static let boardOffsetY: CGFloat = 6
    }
}


