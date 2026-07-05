import SwiftUI
import UIKit
import MaohuobanDesignSystem

// AIAssistantMessageActionsBar AI 回复底部操作栏
// 核心职责：
// - 承载复制、分享和引用来源入口
// - 将剪贴板写入限定在用户点击事件中
struct AIAssistantMessageActionsBar: View {
    let messageText: String
    let references: [AIAssistantReference]
    let onOpenReference: (AIAssistantReference) -> Void

    @State private var isReferenceSheetPresented = false

    private var summaries: [AIAssistantReferenceSourceSummary] {
        AIAssistantReferenceSourceSummary.summaries(from: references)
    }

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            AIAssistantMessageActionIconButton(
                systemImage: "doc.on.doc",
                accessibilityLabel: "复制回答",
                action: copyMessageText
            )

            AIAssistantMessageActionIconButton(
                systemImage: "square.and.arrow.up",
                accessibilityLabel: "分享回答",
                action: shareMessage
            )

            if summaries.isEmpty == false {
                Button {
                    isReferenceSheetPresented = true
                } label: {
                    AIAssistantReferenceSourceSummaryStrip(summaries: summaries)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看引用来源")
            }
        }
        .sheet(isPresented: $isReferenceSheetPresented) {
            AIAssistantReferenceSourceSheet(
                references: references,
                onOpenReference: { reference in
                    isReferenceSheetPresented = false
                    onOpenReference(reference)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func copyMessageText() {
        UIPasteboard.general.string = messageText
    }

    private func shareMessage() {
        // TODO: 接入正式分享流程。
    }
}
