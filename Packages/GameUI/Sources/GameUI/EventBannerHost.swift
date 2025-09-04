import SwiftUI

@MainActor
public struct EventBannerHost<Content: View>: View {
    @Binding private var isPresented: Bool
    @Binding private var bannerText: String
    private let onConfigure: ((@escaping (_ text: String) -> Void, @escaping () -> Void) -> Void)?
    private let content: Content
    
    /// Creates a host container capable of presenting a transient event banner.
    /// - Parameters:
    ///   - isPresented: Controls banner visibility. Can be driven externally.
    ///   - text: The banner message text. Can be driven externally.
    ///   - onConfigure: Optional callback that provides `show(text:)` and `dismiss()` closures to the caller for imperative control.
    ///   - content: Underlying content the banner overlays.
    public init(
        isPresented: Binding<Bool>,
        text: Binding<String>,
        onConfigure: ((@escaping (_ text: String) -> Void, @escaping () -> Void) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self._bannerText = text
        self.onConfigure = onConfigure
        self.content = content()
        
        if let onConfigure {
            let presentedBinding = isPresented
            let textBinding = text
            onConfigure(
                { message in
                    textBinding.wrappedValue = message
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        presentedBinding.wrappedValue = true
                    }
                },
                {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        presentedBinding.wrappedValue = false
                    }
                }
            )
        }
    }
    
    public var body: some View {
        content
            .safeAreaInset(edge: .top) {
                Group {
                    if isPresented {
                        bannerView(text: bannerText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Event banner")
                            .accessibilityValue(bannerText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
    }
    
    @ViewBuilder
    private func bannerView(text: String) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                //.foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    //.foregroundStyle(.white.opacity(0.9))
                    .accessibilityLabel("Dismiss")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
        )
    }
}


