import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactHoldOverlayRing 快捷事实确认进度环
// 核心职责：
// - 展示长按确认的中心进度反馈
// - 在完成阶段切换为成功确认态
struct HomeQuickFactHoldOverlayRing: View {
    let state: HomeQuickFactHoldOverlayState

    @State private var pulse = false

    var body: some View {
        TimelineView(.animation) { context in
            let progress = progress(at: context.date)

            ZStack {
                Circle()
                    .fill(state.accentColor.opacity(pulse ? 0.2 : 0.1))
                    .frame(width: 138, height: 138)
                    .scaleEffect(pulse ? 1.12 : 0.98)

                Circle()
                    .stroke(state.accentColor.opacity(0.16), lineWidth: 11)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        state.accentColor,
                        style: StrokeStyle(lineWidth: 11, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 110, height: 110)

                Circle()
                    .fill(state.accentColor.opacity(0.12 + progress * 0.14))
                    .frame(width: 82, height: 82)

                Image(systemName: state.phase == .completed ? "checkmark" : state.action.systemImage)
                    .font(.system(size: state.phase == .completed ? 38 : 34, weight: .bold))
                    .foregroundStyle(state.accentColor)
                    .symbolEffect(.bounce, value: state.phase == .completed)

                HomeQuickFactHoldOverlaySparkles(
                    accentColor: state.accentColor,
                    isActive: state.phase == .completed
                )
            }
        }
        .onAppear(perform: startPulse)
        .onChange(of: state) {
            startPulse()
        }
    }

    private func progress(at date: Date) -> CGFloat {
        guard state.phase != .completed else { return 1 }

        let referenceDate = state.phase == .cancelled ? state.endedAt ?? date : date
        let elapsed = referenceDate.timeIntervalSince(state.startedAt)
        return min(1, max(0.02, elapsed / HomeQuickFactAction.holdConfirmationSeconds))
    }

    private func startPulse() {
        pulse = false

        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}
