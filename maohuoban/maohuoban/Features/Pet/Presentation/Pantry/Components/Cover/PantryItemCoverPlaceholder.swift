import SwiftUI

// PantryItemCoverPlaceholder 物品照片默认占位
// 核心职责：
// - 提供添加物品照片的统一视觉提示
// - 保持添加态和编辑态封面区域一致
struct PantryItemCoverPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(Color(hex: "7F8C8D"))

            Text("添加物品照片")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "7F8C8D"))
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "EDF1F6"), Color(hex: "D7DFEA")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
