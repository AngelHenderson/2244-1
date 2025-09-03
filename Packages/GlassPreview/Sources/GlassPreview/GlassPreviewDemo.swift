import SwiftUI

/// Demo view showcasing Glass Preview functionality
public struct GlassPreviewDemo: View {
    @State private var selectedConfig: ConfigOption = .balanced
    @State private var customSeed: String = ""
    @State private var showDebug = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text("Glass Preview Row")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("2244 Game Feature Demo")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Configuration Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configuration")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Picker("Config", selection: $selectedConfig) {
                        ForEach(ConfigOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(selectedConfig.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // Custom Seed
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Seed (Optional)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    TextField("Enter seed number", text: $customSeed)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if canImport(UIKit)
                        .keyboardType(.numberPad)
                        #endif
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // Launch Button
                NavigationLink(destination: gameView) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Glass Preview Game")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // Feature Highlights
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    FeatureRow(
                        icon: "sparkles",
                        title: "Glass Preview Row",
                        description: "Upcoming tiles spawn in glass bubbles above the grid"
                    )
                    
                    FeatureRow(
                        icon: "hammer.fill",
                        title: "Power-up Rewards",
                        description: "Shatter glass to earn hammers, swaps, and more"
                    )
                    
                    FeatureRow(
                        icon: "link",
                        title: "2244 Linking",
                        description: "8-direction chains with same or double values"
                    )
                    
                    FeatureRow(
                        icon: "gear",
                        title: "Debug Tools",
                        description: "Comprehensive testing and analytics HUD"
                    )
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .background(Color(hex: "020617").ignoresSafeArea())
            #if canImport(UIKit)
            .navigationBarHidden(true)
            #endif
        }
        #if canImport(UIKit)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    private var gameView: some View {
        let seed = UInt64(customSeed) ?? UInt64(Date().timeIntervalSince1970)
        return GlassPreview.gameView(
            seed: seed,
            config: selectedConfig.config
        )
    }
}

// MARK: - Configuration Options

enum ConfigOption: CaseIterable {
    case balanced
    case generous
    case challenging
    case testing
    
    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .generous: return "Generous"
        case .challenging: return "Hard"
        case .testing: return "Test"
        }
    }
    
    var description: String {
        switch self {
        case .balanced:
            return "Standard gameplay with balanced rewards"
        case .generous:
            return "More frequent rewards and lenient rules"
        case .challenging:
            return "Fewer rewards with more destructive power-ups"
        case .testing:
            return "Testing configuration with guaranteed rewards"
        }
    }
    
    var config: GlassGameStore.Config {
        switch self {
        case .balanced:
            return .balanced
        case .generous:
            return .generous
        case .challenging:
            return .challenging
        case .testing:
            return GlassGameStore.Config(
                giftWeights: [.hammer: 100, .swap: 0, .magnet: 0, .shuffle: 0, .undo: 0, .bomb: 0],
                giftOnAutoDrop: true,
                backgroundColorHex: "#020617"
            )
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    GlassPreviewDemo()
}
