import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryPermissionView 照片权限空态
// 核心职责：
// - 告知用户当前无法读取照片
// - 提供跳转系统设置入口
struct MHBPhotoLibraryPermissionView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: MHBTheme.Spacing.s1) {
                Text("无法访问照片")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text("请在系统设置中允许访问照片")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button(action: onOpenSettings) {
                Text("前往设置")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.primary.color, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
    }
}
