import SwiftUI
import GameApp

struct PauseSheet: View {
    @Environment(\.gameStore) private var gameStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorBlindMode) private var colorBlind
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "raised-3d-square"
    @AppStorage("selectedBackgroundThemeId") private var selectedBackgroundId: String = "city_1"
    let onResume: () -> Void
    let onRestart: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Resume", action: onResume)
                    Button("Restart", role: .destructive, action: onRestart)
                }
                Section("Accessibility") {
                    Toggle("Color blind mode", isOn: bindingColorBlind)
                }
                Section("Tile Theme") {
                    Picker("Tile Style", selection: $selectedThemeId) {
                        ForEach(ThemeRegistry.Default.allDescriptors(), id: \.id) { descriptor in
                            Text(descriptor.name).tag(descriptor.id)
                        }
                    }
                }
                Section("Background Theme") {
                    Picker("Background", selection: $selectedBackgroundId) {
                        let themesByCategory = BackgroundThemeRegistry.Default.themesByCategory()
                        ForEach(themesByCategory.keys.sorted(), id: \.self) { category in
                            Section {
                                ForEach(themesByCategory[category] ?? [], id: \.id) { theme in
                                    Label(theme.name, systemImage: backgroundIcon(for: theme.category))
                                        .tag(theme.id)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("Paused")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .trackScreen(.pause)
    }
    
    private func backgroundIcon(for category: String) -> String {
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
    
    private var bindingColorBlind: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "colorBlindMode") },
            set: { newValue in
                UserDefaults.standard.set(newValue, forKey: "colorBlindMode")
            }
        )
    }
}


