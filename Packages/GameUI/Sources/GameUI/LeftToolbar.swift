import SwiftUI
import GameApp

struct LeftToolbar: View {
    let onPause: () -> Void
    let onShop: () -> Void
    let onAdGift: () -> Void
    let onHome: () -> Void
    
    var body: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            toolbarButton(system: "house.fill", title: "HOME", action: onHome)
            toolbarButton(system: "pause.fill", title: "PAUSE", action: onPause)
            toolbarButton(system: "shippingbox.fill", title: "SHOP", action: onShop)
            toolbarButton(system: "gift.fill", title: "+GEMS", action: onAdGift)
        }
    }
    
    private func toolbarButton(system: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Group {
                    if let img = assetImage(forTitle: title) {
                        img
                    } else {
                        Image(systemName: system)
                    }
                }
                .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .frame(width: Tokens.Size.toolbarButton, height: Tokens.Size.toolbarButton)
            //.foregroundStyle(.white)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private func assetImage(forTitle title: String) -> Image? {
        let map: [String: String] = [
            "PAUSE": "btn_pause",
            "SHOP": "btn_shop",
            "+GEMS": "btn_gift"
        ]
        let key = title.uppercased()
        let name = map[key]
        #if canImport(UIKit)
        if let n = name, let img = UIImage(named: n) { return Image(uiImage: img) }
        #elseif canImport(AppKit)
        if let n = name, let img = NSImage(named: n) { return Image(nsImage: img) }
        #endif
        return nil
    }
}


