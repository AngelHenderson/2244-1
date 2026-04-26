import SwiftUI
import GameApp
#if canImport(UIKit)
import UIKit
#endif

public struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"
    @AppStorage("selectedBackgroundThemeId") private var selectedBackgroundId: String = "city_1"
    @AppStorage("selectedWallpaperId") private var selectedWallpaperId: String = "wallpaper_default"
    @AppStorage("selectedPlayButtonColorId") private var selectedPlayButtonColorId: String = "green"
    @State private var selectedTab: ThemeTab = .tiles

    private enum ThemeTab: String, CaseIterable {
        case tiles = "Tiles"
        case backgrounds = "Backgrounds"
        case wallpapers = "Wallpapers"
        case playButton = "Play Button"
    }

    #if canImport(UIKit)
    private static let segmentedControlAppearanceConfigured: Bool = {
        let font = UIFont(name: "AvenirNext-Medium", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .medium)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: font], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: font], for: .selected)
        return true
    }()
    #endif

    private let tileColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private let backgroundColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    public init() {}

    public var body: some View {
        #if canImport(UIKit)
        let _ = Self.segmentedControlAppearanceConfigured
        #endif
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Theme Type", selection: $selectedTab) {
                    ForEach(ThemeTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    switch selectedTab {
                    case .tiles:
                        tileThemesContent
                    case .backgrounds:
                        backgroundThemesContent
                    case .wallpapers:
                        wallpapersContent
                    case .playButton:
                        playButtonColorsContent
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Theme")
            .platformNavigationTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .platformTopBarTrailing) {
                    HStack(spacing: 12) {
                        GemBalancePill()
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private var tileThemesContent: some View {
        LazyVGrid(columns: tileColumns, spacing: 16) {
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

    private var backgroundThemesContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            let themesByCategory = BackgroundThemeRegistry.Default.themesByCategory()
            let sortedCategories = ["Desert", "Snow", "City", "Jungle", "Underwater", "Solid"]
                .filter { themesByCategory[$0] != nil }

            ForEach(sortedCategories, id: \.self) { category in
                BackgroundCategorySection(
                    category: category,
                    themes: themesByCategory[category] ?? [],
                    selectedId: selectedBackgroundId,
                    onSelect: { id in
                        selectedBackgroundId = id
                    }
                )
            }
        }
        .padding()
    }

    private var wallpapersContent: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(WallpaperThemeRegistry.Default.allWallpapers(), id: \.id) { wallpaper in
                WallpaperCard(
                    wallpaper: wallpaper,
                    isSelected: selectedWallpaperId == wallpaper.id,
                    onSelect: { selectedWallpaperId = wallpaper.id }
                )
            }
        }
        .padding()
    }

    private var playButtonColorsContent: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(PlayButtonColor.allColors, id: \.id) { colorOption in
                PlayButtonColorCard(
                    colorOption: colorOption,
                    isSelected: selectedPlayButtonColorId == colorOption.id,
                    onSelect: { selectedPlayButtonColorId = colorOption.id }
                )
            }
        }
        .padding()
    }
}

// MARK: - Play Button Color Model

public struct PlayButtonColor: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let color: Color

    public static let allColors: [PlayButtonColor] = [
        PlayButtonColor(id: "green", name: "Green", color: .green),
        PlayButtonColor(id: "blue", name: "Blue", color: .blue),
        PlayButtonColor(id: "red", name: "Red", color: .red),
        PlayButtonColor(id: "orange", name: "Orange", color: .orange),
        PlayButtonColor(id: "purple", name: "Purple", color: .purple),
        PlayButtonColor(id: "pink", name: "Pink", color: .pink),
        PlayButtonColor(id: "cyan", name: "Cyan", color: .cyan),
        PlayButtonColor(id: "yellow", name: "Yellow", color: .yellow),
        PlayButtonColor(id: "mint", name: "Mint", color: .mint),
        PlayButtonColor(id: "indigo", name: "Indigo", color: .indigo),
        PlayButtonColor(id: "teal", name: "Teal", color: .teal),
        PlayButtonColor(id: "brown", name: "Brown", color: .brown),
    ]

    public static func color(for id: String) -> Color {
        allColors.first { $0.id == id }?.color ?? .green
    }
}

// MARK: - Play Button Color Card

private struct PlayButtonColorCard: View {
    let colorOption: PlayButtonColor
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Preview of play button with this color
                Image(systemName: "play.fill")
                    .font(.avenirNext(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(colorOption.color, in: Circle())
                    .shadow(color: colorOption.color.opacity(0.4), radius: 4, y: 2)

                Text(colorOption.name)
                    .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.avenirNext(size: GameFonts.title3Size, weight: .regular))
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tile Theme Components

private struct ThemeCard: View {
        let descriptor: ThemeDescriptor
        let isSelected: Bool
        let onSelect: () -> Void
        
        private let sampleValues = [2, 4, 8, 16, 32, 64]
        
        var body: some View {
            Button {
                onSelect()
            } label: {
                VStack(spacing: 12) {
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
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Text(descriptor.name)
                        .font(.avenirNext(size: GameFonts.subheadlineSize, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.avenirNext(size: GameFonts.title2Size, weight: .regular))
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
                                .font(.avenirNext(size: 10, weight: .bold))
                                .foregroundStyle(textColor)
                        }
                } else {
                    RoundedRectangle(cornerRadius: tileCornerRadius)
                        .fill(color)
                        .overlay {
                            Text("\(value)")
                                .font(.avenirNext(size: 10, weight: .bold))
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
    
    private struct MiniTile3DStyle: ViewModifier {
        let baseColor: Color
        let tileShape: ThemeDescriptor.TileShape
        
        func body(content: Content) -> some View {
            let cornerRadius: CGFloat = tileShape == .square ? 4 : 8
            
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(baseColor.opacity(0.6))
                            .offset(y: 2)
                        
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
    
    // MARK: - Background Theme Components
    
    private struct BackgroundCategorySection: View {
        let category: String
        let themes: [BackgroundTheme]
        let selectedId: String
        let onSelect: (String) -> Void
        
        private let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Label(category, systemImage: categoryIcon)
                    .font(.avenirNext(size: GameFonts.headlineSize, weight: .semibold))
                    .foregroundStyle(.primary)
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(themes, id: \.id) { theme in
                        BackgroundCard(
                            theme: theme,
                            isSelected: selectedId == theme.id,
                            onSelect: { onSelect(theme.id) }
                        )
                    }
                }
            }
        }
        
        private var categoryIcon: String {
            switch category {
            case "City": return "building.2.fill"
            case "Desert": return "sun.max.fill"
            case "Jungle": return "leaf.fill"
            case "Snow": return "snowflake"
            case "Underwater": return "drop.fill"
            case "Solid": return "square.fill"
            default: return "photo.fill"
            }
        }
    }
    
    private struct BackgroundCard: View {
        let theme: BackgroundTheme
        let isSelected: Bool
        let onSelect: () -> Void
        
        var body: some View {
            Button(action: onSelect) {
                VStack(spacing: 8) {
                    BackgroundPreview(theme: theme)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .overlay(alignment: .topTrailing) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.avenirNext(size: GameFonts.title3Size, weight: .regular))
                                    .foregroundStyle(.white, Color.accentColor)
                                    .offset(x: 6, y: -6)
                            }
                        }

                    Text(theme.name)
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private struct BackgroundPreview: View {
        let theme: BackgroundTheme
        
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    if theme.imageName.isEmpty {
                        LinearGradient(
                            colors: [
                                Color(hex: "1a1a2e"),
                                Color(hex: "16213e")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Image(theme.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                        
                        if theme.overlayOpacity > 0 {
                            Color.black.opacity(theme.overlayOpacity)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Wallpaper Components
    
    private struct WallpaperCard: View {
        let wallpaper: WallpaperTheme
        let isSelected: Bool
        let onSelect: () -> Void
        
        var body: some View {
            Button(action: onSelect) {
                VStack(spacing: 8) {
                    WallpaperPreview(wallpaper: wallpaper)
                        .aspectRatio(9/16, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .overlay(alignment: .topTrailing) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.avenirNext(size: GameFonts.title3Size, weight: .regular))
                                    .foregroundStyle(.white, Color.accentColor)
                                    .offset(x: 6, y: -6)
                            }
                        }

                    Text(wallpaper.name)
                        .font(.avenirNext(size: GameFonts.caption1Size, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private struct WallpaperPreview: View {
        let wallpaper: WallpaperTheme
        
        var body: some View {
            GeometryReader { geo in
                ZStack {
                    if wallpaper.imageName.isEmpty {
                        LinearGradient(
                            colors: [
                                Color(hex: "1a1a2e"),
                                Color(hex: "16213e")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Image(wallpaper.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                        
                        if wallpaper.overlayOpacity > 0 {
                            Color.black.opacity(wallpaper.overlayOpacity)
                        }
                    }
                }
            }
        }
    }
    
    #Preview {
        ThemePickerView()
    }
