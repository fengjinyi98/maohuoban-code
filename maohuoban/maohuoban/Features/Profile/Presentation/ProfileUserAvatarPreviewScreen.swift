import SwiftUI
import MaohuobanDesignSystem
import UIKit

// ProfileUserAvatarPreviewScreen 用户头像预览页
// 核心职责：
// - 提供当前用户头像的沉浸式预览
// - 复用系统图片选择和圆形裁剪基础设施完成前端本地更新
struct ProfileUserAvatarPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let displayName: String
    let avatarAssetName: String
    let avatarURLString: String?
    let localAvatarImage: UIImage?
    let onAvatarUpdated: (UIImage) async -> Bool

    @State private var previewImage: UIImage?
    @State private var isMediaPickerPresented = false
    @State private var cropTarget: MHBIdentifiableUIImage?
    @State private var saveState = ProfileUserAvatarSaveState.idle

    init(
        displayName: String,
        avatarAssetName: String,
        avatarURLString: String?,
        localAvatarImage: UIImage?,
        onAvatarUpdated: @escaping (UIImage) async -> Bool
    ) {
        self.displayName = displayName
        self.avatarAssetName = avatarAssetName
        self.avatarURLString = avatarURLString
        self.localAvatarImage = localAvatarImage
        self.onAvatarUpdated = onAvatarUpdated
        _previewImage = State(initialValue: localAvatarImage)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s3)

                Spacer()

                avatarPreview

                saveStatus
                    .padding(.top, MHBTheme.Spacing.s4)

                Spacer()

                selectAvatarButton
                    .padding(.horizontal, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isMediaPickerPresented) {
            MHBSystemMediaPicker(
                request: .singleImage,
                onComplete: { result in
                    isMediaPickerPresented = false
                    handleMediaPickerResult(result)
                },
                onCancel: {
                    isMediaPickerPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $cropTarget) { target in
            MHBCircularImageCropScreen(
                originalImage: target.image,
                title: "裁剪头像",
                onCancel: {
                    cropTarget = nil
                },
                onSave: handleCroppedAvatar
            )
        }
        .accessibilityIdentifier("profile.userAvatarPreview.screen")
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("关闭")

            Spacer()

            Text(displayName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFill()
                .frame(width: 320, height: 320)
                .clipShape(Circle())
        } else if let avatarURLString,
                  let url = MHBBackendEndpoint.resolve(avatarURLString) {
            MHBRemoteImage(url: url, contentMode: .fill) {
                fallbackAvatar
            }
            .frame(width: 320, height: 320)
            .clipShape(Circle())
        } else if avatarAssetName.isEmpty == false {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 320, height: 320)
                .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 126, weight: .semibold))
            .foregroundStyle(.white.opacity(0.48))
            .frame(width: 320, height: 320)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
    }

    @ViewBuilder
    private var saveStatus: some View {
        switch saveState {
        case .idle:
            Text("当前头像")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.66))
        case .saving:
            HStack(spacing: MHBTheme.Spacing.s2) {
                ProgressView()
                    .tint(.white)

                Text("正在保存头像...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.76))
            }
        case .saved:
            Text("头像已保存")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.76))
        }
    }

    private var selectAvatarButton: some View {
        Button {
            isMediaPickerPresented = true
        } label: {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text("选择头像")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white.opacity(0.14), in: .rect(cornerRadius: MHBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func handleMediaPickerResult(_ result: MHBMediaPickerResult) {
        guard let image = result.images.first else {
            return
        }

        cropTarget = MHBIdentifiableUIImage(image: image)
    }

    private func handleCroppedAvatar(_ image: UIImage) {
        cropTarget = nil
        saveState = .saving

        Task { @MainActor in
            let didSave = await onAvatarUpdated(image)
            if didSave {
                previewImage = image
            }
            saveState = didSave ? .saved : .idle
        }
    }
}

private enum ProfileUserAvatarSaveState {
    case idle
    case saving
    case saved
}
