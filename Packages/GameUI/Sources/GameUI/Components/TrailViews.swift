import SwiftUI

/// A dotted vertical trail connector between tiles
public struct DottedTrail: View {
    public var dotSize: CGFloat
    public var spacing: CGFloat
    public var color: Color

    public init(dotSize: CGFloat = 6, spacing: CGFloat = 14, color: Color = .white.opacity(0.6)) {
        self.dotSize = dotSize
        self.spacing = spacing
        self.color = color
    }

    public var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Draw a vertical line down the center
                path.move(to: CGPoint(x: dotSize / 2, y: 0))
                path.addLine(to: CGPoint(x: dotSize / 2, y: geometry.size.height))
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: dotSize,
                    lineCap: .round,
                    dash: [0.1, spacing]
                )
            )
            .frame(width: dotSize) // Constrain path width
            .frame(maxWidth: .infinity) // Center in available space
        }
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

/// A curved S-trail connector between tiles
public struct CurvedTrailView: View {
    public var color: Color
    public var lineWidth: CGFloat

    public init(color: Color = .white.opacity(0.6), lineWidth: CGFloat = 4) {
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        CurvedTrailShape()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: 40)
    }
}

#Preview("Dotted Trail") {
    VStack {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 100, height: 100)
        
        DottedTrail(dotSize: 7, spacing: 15, color: .white.opacity(0.5))
            .frame(height: 60)
        
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 100, height: 100)
    }
    .padding()
    .background(Color.black)
}

#Preview("Curved Trail") {
    VStack {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 100, height: 100)
        
        CurvedTrailView(color: .cyan.opacity(0.7), lineWidth: 5)
            .frame(height: 60)
        
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray)
            .frame(width: 100, height: 100)
    }
    .padding()
    .background(Color.black)
}
