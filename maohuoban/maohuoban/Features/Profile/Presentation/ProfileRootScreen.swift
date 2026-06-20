import SwiftUI
import MaohuobanDesignSystem

// ProfileRootScreen 我的 Tab 根视图
// 核心职责：
// - 作为"我的"Tab NavigationStack 的根内容
// - 承载个人信息概览和系统导航栏工具入口
struct ProfileRootScreen: View {
    let onLogout: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: MHBTheme.Spacing.s3) {
                ProfileAccountSummarySection(profile: ProfileAccountSummary.mock)

                ProfileQuickEntriesSection(items: ProfileQuickEntryItem.mockItems) { item in
                    print("Tapped quick entry: \(item.title)")
                }

                ProfileFAQBanner {
                    print("Tapped FAQ banner")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .padding(.top, MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s6)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .accessibilityIdentifier("profile.scrollView")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("设置")
                .accessibilityIdentifier("profile.settingsButton")
            }
        }
    }
}
