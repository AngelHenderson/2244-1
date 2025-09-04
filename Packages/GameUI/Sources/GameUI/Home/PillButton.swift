import SwiftUI

struct PillButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = icon { 
                    Image(systemName: icon)
                        .imageScale(.large)
                        //.foregroundStyle(.white)
                }
                Text(title)
                    .font(.title2.weight(.bold))
                    //.foregroundStyle(.white)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.8)],
                    startPoint: .topLeading, 
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
        }
        .accessibilityLabel(title)
    }
}
