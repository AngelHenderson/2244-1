import SwiftUI

struct TileBadge: View {
    let value: Int
    let style: Style
    var showClaimBadge: Bool = false
    var isClaimed: Bool = false

    enum Style { 
        case primary, secondary, locked 
        
        var isLocked: Bool {
            self == .locked
        }
    }

    var body: some View {
        let size: CGFloat = style == .primary ? 140 : 80
        ZStack {
            ZStack {
                Text(formatValue(value))
                    .font(.system(size: style == .primary ? 44 : 28, weight: .bold))
                    //.foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if style == .locked {
                    VStack{
                        Image("lockpic")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .padding(.top, 4)

                        Spacer()
                    }
                    .frame(width: size, height: size)

                }
            }



            // Claim indicator badge
            if showClaimBadge && !style.isLocked {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("!")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                    Spacer()
                }
                .frame(width: size, height: size)
                .padding(6)
            }
            
            // Claimed checkmark
            if isClaimed && !style.isLocked {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.green)
                            .background(Circle().fill(.white))
                    }
                    Spacer()
                }
                .frame(width: size, height: size)
                .padding(6)
            }
        }
        .accessibilityLabel(accessibility)
    }
    
    private func formatValue(_ value: Int) -> String {
        // Always show exact numeric value (e.g., 1024, 2048), no abbreviations
        return String(value)
    }

    private var background: some ShapeStyle {
        switch style {
        case .primary: 
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary: 
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .locked: 
            return LinearGradient(
                colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var accessibility: String {
        switch style {
        case .primary: "Highest tile \(value)"
        case .secondary: "Milestone \(value)"
        case .locked: "Locked milestone \(value)"
        }
    }
}
