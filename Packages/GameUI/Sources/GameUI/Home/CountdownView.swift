import SwiftUI

struct CountdownView: View {
    let deadline: Date
    @State private var now = Date()
    @State private var timer: Timer?

    var body: some View {
        Text(timeString)
            .monospacedDigit()
            .font(.caption.bold())
            //.foregroundStyle(.white)
            .onAppear { startTimer() }
            .onDisappear { stopTimer() }
    }

    private var remaining: TimeInterval { 
        max(0, deadline.timeIntervalSince(now)) 
    }

    private var timeString: String {
        let seconds = Int(remaining.rounded())
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                now = Date()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
