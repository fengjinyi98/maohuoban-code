import SwiftUI

// PetWorldFeedDetailCommentInputShield 评论输入遮罩
// 核心职责：
// - 在键盘评论输入出现时拦截页面上方空白区域点击
// - 避免触发底层大图预览、双击点赞和卡片手势
struct PetWorldFeedDetailCommentInputShield: View {
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭评论输入")
    }
}
