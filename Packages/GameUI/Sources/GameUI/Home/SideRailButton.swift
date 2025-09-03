import SwiftUI

struct SideRailButton: View {
    let systemImage: String?
    let customImage: String?
    let title: String
    var badge: Bool = false
    var locked: Bool = false
    var specialLabel: String? = nil // For things like "+73" gems
    var action: () -> Void

    var body: some View {
        Button(action: { if !locked { action() } }) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    // Icon container
                    ZStack {
                        if let systemImage = systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                        } else if let customImage = customImage {
                            Image(customImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .accessibilityHidden(true)
                        }
                        
                        if let specialLabel = specialLabel {
                            Text(specialLabel)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        if locked {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.black.opacity(0.5))
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    
                    // Badge indicator
                    if badge && !locked {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 6, y: -6)
                            .accessibilityHidden(true)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .disabled(locked)
        .accessibilityLabel("\(title)\(locked ? ", locked" : "")")
    }
}
