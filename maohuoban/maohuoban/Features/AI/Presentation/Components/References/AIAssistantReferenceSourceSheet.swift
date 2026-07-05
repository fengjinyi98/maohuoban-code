import SwiftUI
import MaohuobanDesignSystem

// AIAssistantReferenceSourceSheet AI 引用来源面板
// 核心职责：
// - 以系统 sheet 展示回答引用明细
// - 将可跳转引用的打开意图交给上层路由
struct AIAssistantReferenceSourceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let references: [AIAssistantReference]
    let onOpenReference: (AIAssistantReference) -> Void

    private var presentations: [AIAssistantReferenceSourcePresentation] {
        references.map(AIAssistantReferenceSourcePresentation.init(reference:))
    }

    var body: some View {
        NavigationStack {
            MHBScreenScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(presentations.enumerated()), id: \.element.id) { index, presentation in
                        AIAssistantReferenceSourceRow(
                            presentation: presentation,
                            onOpenReference: onOpenReference
                        )

                        if index < presentations.count - 1 {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.top, MHBTheme.Spacing.s3)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("引用来源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
