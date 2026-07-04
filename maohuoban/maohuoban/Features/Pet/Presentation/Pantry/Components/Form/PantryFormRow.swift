import SwiftUI

// PantryFormRow 储物柜表单文本行
// 核心职责：
// - 统一物品表单的标签和输入框布局
// - 绑定调用方持有的表单草稿字段
struct PantryFormRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "888888"))
                .frame(width: 80, alignment: .leading)

            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(Color(hex: "CCCCCC")))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(hex: "2A2A2A"))
        }
        .padding(.vertical, 16)
    }
}
