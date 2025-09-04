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
        VStack{
            if #available(iOS 26.0, *) {
                Button(action: { if !locked { action() } }) {
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            // Icon container
                            ZStack {
                                if let systemImage = systemImage {
                                    Image(systemName: systemImage)
                                        .font(.system(size: 24, weight: .semibold))
                                    //.foregroundStyle(.white)
                                } else if let customImage = customImage {
                                    Image(customImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .accessibilityHidden(true)
                                }

                                if let specialLabel = specialLabel {
                                    Text(specialLabel)
                                        .font(.caption.bold())
                                    //.foregroundStyle(.white)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .overlay {
                                if locked {
                                    ZStack {
                                        Image("lockpic")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
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

                    }
                }
                .buttonStyle(.glass)

                //        .glassEffectCompat(cornerRadius: 8)
                .disabled(locked)
                .accessibilityLabel("\(title)\(locked ? ", locked" : "")")


            } else {
                // Fallback on earlier versions
            }


            Text(title)
                .font(.caption2)
                .fontWeight(.heavy)
            //.foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }

    }
}
 
