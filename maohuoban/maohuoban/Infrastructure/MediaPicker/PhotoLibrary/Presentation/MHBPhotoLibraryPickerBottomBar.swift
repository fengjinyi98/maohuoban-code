import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryPickerBottomBar 照片选择器底部确认栏
// 核心职责：
// - 展示当前选择数量
// - 承载多选确认入口
struct MHBPhotoLibraryPickerBottomBar: View {
    let selectedCountText: String
    let hasSelection: Bool
    let isResolvingSelection: Bool
    let onConfirm: () -> Void

    var body: some View {
        HStack {
            Text("已选择 \(selectedCountText)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(hasSelection ? 0.9 : 0.55))

            Spacer()

            Button(action: onConfirm) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    if isResolvingSelection {
                        ProgressView()
                            .tint(.white)
                    }

                    Text("完成")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .frame(height: 40)
                .background(
                    hasSelection
                        ? MHBTheme.ColorToken.primary.color
                        : Color.white.opacity(0.18),
                    in: .capsule
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasSelection || isResolvingSelection)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .frame(height: 64)
        .background(Color.black)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
        }
    }
}
