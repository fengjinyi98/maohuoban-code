import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailMissingScreen 宠物世界详情缺失页面
// 核心职责：
// - 展示无法找到帖子详情时的轻量占位
// - 保持系统导航返回能力可用
struct PetWorldFeedDetailMissingScreen: View {
    var body: some View {
        Text("这条动态暂时不可查看")
            .font(MHBTheme.Typography.body)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
    }
}
