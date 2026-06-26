import SwiftUI
import MaohuobanDesignSystem

// ThinkingDots 思考中三点动画
// 核心职责：
// - 流式占位消息文本为空时展示加载动画
// - 通过轻量相位变化表达助手正在生成
struct ThinkingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 6, height: 6)
                    .opacity(phase == index ? 1 : 0.3)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.smooth(duration: 0.2)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
