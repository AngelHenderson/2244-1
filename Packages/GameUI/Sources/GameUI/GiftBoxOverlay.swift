import SwiftUI

struct GiftBoxOverlay: View {
    let size: CGFloat
    
    private var boxSize: CGFloat {
        max(12, size * 0.78)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: boxSize * 0.25, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.64, blue: 0.16),
                            Color(red: 0.94, green: 0.28, blue: 0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: boxSize * 0.12, x: 0, y: boxSize * 0.08)
                .overlay(
                    RoundedRectangle(cornerRadius: boxSize * 0.25, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                )
            
            VStack(spacing: 2) {
                Image(systemName: "gift.fill")
                    .font(.system(size: boxSize * 0.45, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                Text("Tap")
                    .font(.system(size: boxSize * 0.2, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .frame(width: boxSize, height: boxSize)
        .accessibilityLabel("Gift reward")
    }
}



