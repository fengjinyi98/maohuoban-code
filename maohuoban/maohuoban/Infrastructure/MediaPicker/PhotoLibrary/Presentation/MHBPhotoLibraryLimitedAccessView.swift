import MaohuobanDesignSystem
import PhotosUI
import SwiftUI
import UIKit

// MHBPhotoLibraryLimitedBanner 有限照片访问提示
// 核心职责：
// - 提示用户当前只能访问部分照片
// - 提供扩展有限访问范围的入口
struct MHBPhotoLibraryLimitedBanner: View {
    let onOpenLimitedPicker: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)

            Text("仅可访问部分照片")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer()

            Button(action: onOpenLimitedPicker) {
                Text("选择更多")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
    }
}

// MHBPhotoLibraryLimitedPickerPresenter 有限照片访问选择器桥接
// 核心职责：
// - 调起系统有限照片库管理页面
// - 在用户完成后通知业务刷新相册数据
struct MHBPhotoLibraryLimitedPickerPresenter: UIViewControllerRepresentable {
    let onDidFinish: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            await PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
            onDidFinish()
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {}
}
