import SwiftUI
import MaohuobanDesignSystem

// SettingsAddressListScreen 收货地址页面
// 核心职责：
// - 展示 mock 地址列表和默认地址
// - 提供添加与编辑地址入口占位
struct SettingsAddressListScreen: View {
    var body: some View {
        MHBScreenScrollView {
            VStack(spacing: MHBTheme.Spacing.s4) {
                SettingsSection {
                    SettingsRow(title: "阿毛", value: "155****4195", subtitle: "上海市 浦东新区 世纪大道 100 号", showChevron: true)
                    SettingsDivider()
                    SettingsRow(title: "公司地址", value: "默认", subtitle: "杭州市 西湖区 文三路 88 号", showChevron: true)
                }

                Button("新增收货地址") { }
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(MHBTheme.ColorToken.primary.color)
                    .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("收货地址")
        .navigationBarTitleDisplayMode(.inline)
    }
}
