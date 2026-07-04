import SwiftUI

// PantryInteractiveTag 储物柜表单可选标签
// 核心职责：
// - 展示分类和库存状态的选中态
// - 将点击事件转发给表单页面更新草稿
struct PantryInteractiveTag: View {
    let title: String
    let isActive: Bool
    let style: PantryTagStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? activeTextColor : Color(hex: "666666"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? activeBackgroundColor : Color(hex: "F3F4F6"))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var activeBackgroundColor: Color {
        switch style {
        case .green:
            Color(hex: "E8F4ED")
        case .blue:
            Color(hex: "EAF5FF")
        }
    }

    private var activeTextColor: Color {
        switch style {
        case .green:
            Color(hex: "4A8B63")
        case .blue:
            Color(hex: "0093DD")
        }
    }
}
