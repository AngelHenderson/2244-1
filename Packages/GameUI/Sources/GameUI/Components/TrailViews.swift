import SwiftUI

/// A centered dotted vertical trail connector between tiles
/// Uses explicit dot count for perfect centering in the gap
public struct DottedTrail: View {
    public var dotCount: Int
    public var dotSize: CGFloat
    public var dotSpacing: CGFloat
    public var color: Color

    public init(dotCount: Int = 5, dotSize: CGFloat = 8, dotSpacing: CGFloat = 10, color: Color = .white.opacity(0.5)) {
        self.dotCount = dotCount
        self.dotSize = dotSize
        self.dotSpacing = dotSpacing
        self.color = color
    }

    public var body: some View {
        VStack {
            Spacer(minLength: 0)
            
            VStack(spacing: dotSpacing) {
                ForEach(0..<dotCount, id: \.self) { _ in
                    Circle()
                        .fill(color)
                        .frame(width: dotSize, height: dotSize)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// A Shape that draws an S-curve from top-center to bottom-center
public struct CurvedTrailShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addCurve(
            to: CGPoint(x: width / 2, y: height),
            control1: CGPoint(x: width + 10, y: height * 0.3),
            control2: CGPoint(x: -10, y: height * 0.7)
        )

        return path
    }
}

/// A curved S-trail connector between tiles, centered in its frame
public struct CurvedTrailView: View {
    public var color: Color
    public var lineWidth: CGFloat

    public init(color: Color = .white.opacity(0.6), lineWidth: CGFloat = 4) {
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        VStack {
            Spacer(minLength: 0)
            
            CurvedTrailShape()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: 40)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview("Dotted Trail") {
    VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 140, height: 140)
        
        DottedTrail(dotCount: 5, dotSize: 8, dotSpacing: 10, color: .white.opacity(0.5))
            .frame(height: 80)
        
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 140, height: 140)
        
        DottedTrail(dotCount: 5, dotSize: 8, dotSpacing: 10, color: .white.opacity(0.5))
            .frame(height: 80)
        
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 140, height: 140)
    }
    .padding()
    .background(Color.black)
}

#Preview("Curved Trail") {
    VStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 140, height: 140)
        
        CurvedTrailView(color: .cyan.opacity(0.7), lineWidth: 5)
            .frame(height: 80)
        
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 140, height: 140)
    }
    .padding()
    .background(Color.black)
}
