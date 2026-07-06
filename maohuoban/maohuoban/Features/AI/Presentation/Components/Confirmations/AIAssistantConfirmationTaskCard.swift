import SwiftUI
import UIKit
import MaohuobanDesignSystem

// AIAssistantConfirmationTaskCard AI 写入确认卡
// 核心职责：
// - 展示 Agent 准备写入的观察内容
// - 通过用户显式点击触发确认或取消
struct AIAssistantConfirmationTaskCard: View {
    let task: PendingConfirmationTask
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AIAssistantConfirmationTaskCardHeader(title: task.preview.title)

            AIAssistantConfirmationTaskPreviewBlock(
                note: task.preview.note,
                sourceLabel: task.preview.sourceLabel
            )

            HStack {
                Button(confirmLabel) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.82)
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(MHBTheme.ColorToken.primary.color)

                Button(cancelLabel, role: .destructive) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.72)
                    onCancel()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("ai.assistant.confirmationTask")
    }

    private var confirmLabel: String {
        task.actions.first { $0.kind == "approve" }?.label ?? "确认写入"
    }

    private var cancelLabel: String {
        task.actions.first { $0.kind == "reject" }?.label ?? "取消"
    }
}
