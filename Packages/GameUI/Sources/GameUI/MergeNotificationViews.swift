import SwiftUI
import GameApp
import GameCore

struct UnlockedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Tile Unlocked")
                .font(.title2.weight(.bold))
            
            Text("Unlocked")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            TileView(tile: Tile(value: value), isSelected: false, isValid: true, size: 120)
                .accessibilityLabel("Unlocked tile \(value)")
            
            Text(CompactNumberFormatter.format(value))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Button("Continue") { onClose() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}

struct AddedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("New Tile Added")
                .font(.title2.weight(.bold))
            
            Text("Added")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            TileView(tile: Tile(value: value), isSelected: false, isValid: true, size: 120)
                .accessibilityLabel("Added tile \(value)")
            
            Text(CompactNumberFormatter.format(value))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Button("Continue") { onClose() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}

struct ExcludedNotificationView: View {
    let value: Int
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Tile Excluded")
                .font(.title2.weight(.bold))
            
            Text("Eliminated")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            TileView(tile: Tile(value: value), isSelected: false, isValid: true, size: 120)
                .accessibilityLabel("Excluded tile \(value)")
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                        .offset(x: 8, y: -8)
                }
            
            Text(CompactNumberFormatter.format(value))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Button("Continue") { onClose() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}

