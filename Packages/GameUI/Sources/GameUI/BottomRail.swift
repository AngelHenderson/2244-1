import SwiftUI

struct BottomRail: View {
    let reserveLabel: String
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.green)
                    .frame(width: 76, height: 76)
                    .shadow(radius: 6, y: 3)
                Text(reserveLabel)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.yellow)
                    .offset(y: -46)
            }
            Image(systemName: "chevron.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(6)
                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}


