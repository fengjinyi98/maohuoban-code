import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryEmptyView 照片空态
// 核心职责：
// - 展示当前相册没有可用媒体
// - 避免网格空数据时出现空白页
struct MHBPhotoLibraryEmptyView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "photo")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))

            Text("没有可用媒体")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
