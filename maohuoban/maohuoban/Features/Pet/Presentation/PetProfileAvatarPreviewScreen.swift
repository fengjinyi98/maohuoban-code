import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetProfileAvatarPreviewScreen 宠物头像预览页
// 核心职责：
// - 提供当前宠物头像的沉浸式预览
// - 承接选择图片、圆形裁剪和临时上传状态流转
struct PetProfileAvatarPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss

    let petName: String
    let avatarURL: String?
    let species: PetProfileEditProfile.Species
    let localAvatarImage: UIImage?
    let onAvatarUpdated: (UIImage) -> Void

    @State private var previewImage: UIImage?
    @State private var isMediaPickerPresented = false
    @State private var cropTarget: MHBIdentifiableUIImage?
    @State private var uploadState = PetProfileAvatarUploadState.idle

    init(
        petName: String,
        avatarURL: String?,
        species: PetProfileEditProfile.Species,
        localAvatarImage: UIImage?,
        onAvatarUpdated: @escaping (UIImage) -> Void
    ) {
        self.petName = petName
        self.avatarURL = avatarURL
        self.species = species
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

                uploadStatus
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
                title: "裁剪宠物头像",
                onCancel: {
                    cropTarget = nil
                },
                onSave: handleCroppedAvatar
            )
        }
        .accessibilityIdentifier("pet.profileAvatarPreview.screen")
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

            Text(petName)
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
        } else if let avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackAvatar
                }
            }
            .frame(width: 320, height: 320)
            .clipShape(Circle())
        } else {
            fallbackAvatar
        }
    }

    private var fallbackAvatar: some View {
        Image(systemName: species.systemImage)
            .font(.system(size: 126, weight: .semibold))
            .foregroundStyle(.white.opacity(0.48))
            .frame(width: 320, height: 320)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
    }

    @ViewBuilder
    private var uploadStatus: some View {
        switch uploadState {
        case .idle:
            Text("当前宠物头像")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.66))
        case .uploading:
            HStack(spacing: MHBTheme.Spacing.s2) {
                ProgressView()
                    .tint(.white)

                Text("正在保存头像...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.76))
            }
        case .saved:
            Text("头像已临时保存")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.76))
        }
    }

    private var selectAvatarButton: some View {
        Button {
            isMediaPickerPresented = true
        } label: {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Text("选择宠物头像")
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
        previewImage = image
        cropTarget = nil
        uploadState = .uploading

        Task { @MainActor in
            // TODO: 接入后端宠物头像上传接口后，将这里替换为真实上传状态。
            try? await Task.sleep(for: .milliseconds(450))
            onAvatarUpdated(image)
            uploadState = .saved
        }
    }
}

private enum PetProfileAvatarUploadState {
    case idle
    case uploading
    case saved
}
