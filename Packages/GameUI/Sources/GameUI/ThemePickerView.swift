import SwiftUI

public struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ThemeRegistry.Default.allDescriptors(), id: \.id) { descriptor in
                        ThemeCard(
                            descriptor: descriptor,
                            isSelected: selectedThemeId == descriptor.id,
                            onSelect: {
                                selectedThemeId = descriptor.id
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tile Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ThemeCard: View {
    let descriptor: ThemeDescriptor
    let isSelected: Bool
    let onSelect: () -> Void

    // Sample tile values for preview
    private let sampleValues = [2, 4, 8, 16, 32, 64]

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Tile preview grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4),
                    GridItem(.flexible(), spacing: 4)
                ], spacing: 4) {
                    ForEach(sampleValues, id: \.self) { value in
                        ThemePreviewTile(
                            value: value,
                            descriptor: descriptor
                        )
                    }
                }
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Theme name
                Text(descriptor.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ThemePreviewTile: View {
    let value: Int
    let descriptor: ThemeDescriptor

    var body: some View {
        let color = descriptor.color(for: value)
        let textColor = Theme.textColor(for: value)

        Group {
            if descriptor.tileStyle == .raised3D {
                RoundedRectangle(cornerRadius: tileCornerRadius)
                    .fill(Color.clear)
                    .modifier(MiniTile3DStyle(
                        baseColor: color,
                        tileShape: descriptor.tileShape
                    ))
                    .overlay {
                        Text("\(value)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(textColor)
                    }
            } else {
                RoundedRectangle(cornerRadius: tileCornerRadius)
                    .fill(color)
                    .overlay {
                        Text("\(value)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(textColor)
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var tileCornerRadius: CGFloat {
        switch descriptor.tileShape {
        case .square: return 4
        case .rounded: return 8
        }
    }
}

// Mini version of 3D tile style for previews
private struct MiniTile3DStyle: ViewModifier {
    let baseColor: Color
    let tileShape: ThemeDescriptor.TileShape

    func body(content: Content) -> some View {
        let cornerRadius: CGFloat = tileShape == .square ? 4 : 8

        content
            .background(
                ZStack {
                    // Bottom shadow layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(baseColor.opacity(0.6))
                        .offset(y: 2)

                    // Main tile
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    baseColor.opacity(1.0),
                                    baseColor.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Top highlight
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
    }
}

#Preview {
    ThemePickerView()
}
