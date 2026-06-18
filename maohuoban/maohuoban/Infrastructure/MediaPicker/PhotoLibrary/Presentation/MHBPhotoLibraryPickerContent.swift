import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryPickerContent 照片选择器内容区
// 核心职责：
// - 根据授权、加载和空态展示对应内容
// - 承载照片网格和 Limited Library 提示
struct MHBPhotoLibraryPickerContent: View {
    let authorizationStatus: MHBPhotoLibraryAuthorizationStatus
    let isLoading: Bool
    let isResolvingSelection: Bool
    let assets: [MHBPhotoLibraryAsset]
    let resolvingAssetID: String?
    let service: MHBPhotoLibraryService
    let onSelectAsset: (MHBPhotoLibraryAsset) -> Void
    let onOpenSettings: () -> Void
    let onOpenLimitedPicker: () -> Void

    var body: some View {
        switch authorizationStatus {
        case .notDetermined:
            MHBPhotoLibraryLoadingView(text: "正在读取照片...")
        case .restricted, .denied:
            MHBPhotoLibraryPermissionView(onOpenSettings: onOpenSettings)
        case .authorized, .limited:
            MHBPhotoLibraryAuthorizedContent(
                authorizationStatus: authorizationStatus,
                isLoading: isLoading,
                isResolvingSelection: isResolvingSelection,
                assets: assets,
                resolvingAssetID: resolvingAssetID,
                service: service,
                onSelectAsset: onSelectAsset,
                onOpenLimitedPicker: onOpenLimitedPicker
            )
        }
    }
}

// MHBPhotoLibraryAuthorizedContent 已授权照片内容
// 核心职责：
// - 展示有限访问提示和资源网格
// - 在加载、空态和网格之间切换
private struct MHBPhotoLibraryAuthorizedContent: View {
    let authorizationStatus: MHBPhotoLibraryAuthorizationStatus
    let isLoading: Bool
    let isResolvingSelection: Bool
    let assets: [MHBPhotoLibraryAsset]
    let resolvingAssetID: String?
    let service: MHBPhotoLibraryService
    let onSelectAsset: (MHBPhotoLibraryAsset) -> Void
    let onOpenLimitedPicker: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if authorizationStatus == .limited {
                MHBPhotoLibraryLimitedBanner(onOpenLimitedPicker: onOpenLimitedPicker)
            }

            if isLoading {
                MHBPhotoLibraryLoadingView(text: "正在加载照片...")
            } else if assets.isEmpty {
                MHBPhotoLibraryEmptyView()
            } else {
                MHBPhotoGridViewRepresentable(
                    assets: assets,
                    resolvingAssetID: resolvingAssetID,
                    service: service,
                    onSelectAsset: onSelectAsset
                )
                .disabled(isResolvingSelection)
            }
        }
    }
}

// MHBPhotoLibraryLoadingView 照片选择器加载态
// 核心职责：
// - 展示照片库加载进度
// - 占满内容区避免布局跳动
private struct MHBPhotoLibraryLoadingView: View {
    let text: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            ProgressView()
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MHBPhotoLibraryPermissionView 照片权限空态
// 核心职责：
// - 告知用户当前无法读取照片
// - 提供跳转系统设置入口
private struct MHBPhotoLibraryPermissionView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            VStack(spacing: MHBTheme.Spacing.s1) {
                Text("无法访问照片")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("请在系统设置中允许访问照片")
                    .font(.system(size: 14))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
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

// MHBPhotoLibraryEmptyView 照片空态
// 核心职责：
// - 展示当前相册没有可用照片
// - 避免网格空数据时出现空白页
private struct MHBPhotoLibraryEmptyView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "photo")
                .font(.system(size: 52, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("没有可用照片")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
