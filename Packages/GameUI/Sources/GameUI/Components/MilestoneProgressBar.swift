import SwiftUI
import GameCore
import GameApp

public struct QuestMilestoneBar: View {
    let startStep: Int
    let targetStep: Int
    let currentStep: Int

    public init(startStep: Int, targetStep: Int, currentStep: Int) {
        self.startStep = startStep
        self.targetStep = targetStep
        self.currentStep = currentStep
    }

    private var progressRatio: CGFloat {
        let totalSteps = max(1, targetStep - startStep)
        let currentProgress = max(0, currentStep - startStep)
        return min(1.0, CGFloat(currentProgress) / CGFloat(totalSteps))
    }

    private var isCompleted: Bool {
        currentStep >= targetStep
    }

    private var currentLabel: String {
        TileStepLabelFormatter.labelForStep(currentStep, start: 2)
    }

    private var startLabel: String {
        TileStepLabelFormatter.labelForStep(startStep, start: 2)
    }

    private var targetLabel: String {
        TileStepLabelFormatter.labelForStep(targetStep, start: 2)
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Current position indicator (floating above the bar)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 8)

                    // Fill Track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isCompleted ? [.green] : [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progressRatio), height: 8)

                    // Tick marks for each step
                    let totalSteps = targetStep - startStep
                    if totalSteps > 0 && totalSteps <= 20 {
                        HStack(spacing: 0) {
                            ForEach(1..<totalSteps, id: \.self) { i in
                                Spacer(minLength: 0)
                                Circle()
                                    .fill(
                                        i <= (currentStep - startStep)
                                            ? Color.white.opacity(0.5)
                                            : Color(UIColor.systemGray4)
                                    )
                                    .frame(width: 4, height: 4)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    // Current position popup (shows current tile label)
                    if currentStep > startStep && currentStep < targetStep {
                        let popupX = geo.size.width * progressRatio

                        VStack(spacing: 1) {
                            Text(currentLabel)
                                .font(.avenirNext(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue))

                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(.blue)
                        }
                        .fixedSize()
                        .position(x: popupX, y: -6)
                    }
                }
            }
            .frame(height: 28)

            // Start and target labels
            HStack {
                Text(startLabel)
                    .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
                    .foregroundStyle(.secondary)

                Spacer()

                if isCompleted {
                    Text("✓ \(targetLabel)")
                        .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Text(targetLabel)
                        .font(.avenirNext(size: GameFonts.caption2Size, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

#Preview("Quest Milestone Bar") {
    VStack(spacing: 40) {
        // Not started
        QuestMilestoneBar(startStep: 265, targetStep: 275, currentStep: 265)
        // At 30x (step 273)
        QuestMilestoneBar(startStep: 265, targetStep: 275, currentStep: 273)
        // Completed
        QuestMilestoneBar(startStep: 265, targetStep: 275, currentStep: 275)
    }
    .padding(32)
}
