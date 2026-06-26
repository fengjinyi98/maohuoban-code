import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryLoadingView 照片选择器加载态
// 核心职责：
// - 展示照片库加载进度
// - 占满内容区避免布局跳动
struct MHBPhotoLibraryLoadingView: View {
    let text: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            ProgressView()
                .tint(.white)

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
