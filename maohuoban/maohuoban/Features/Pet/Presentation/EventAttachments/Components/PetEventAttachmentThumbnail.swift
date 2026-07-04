import SwiftUI
import MaohuobanDesignSystem

// PetEventAttachmentThumbnail 事件附件缩略图
// 核心职责：
// - 展示本地预览图和即时上传状态
// - 提供单张附件删除与失败重试入口
struct PetEventAttachmentThumbnail: View {
    let attachment: PetEventAttachmentDraft
    let onRemove: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            imageContent
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }

            stateOverlay

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, MHBTheme.ColorToken.labelSecondary.color)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除照片")
        }
        .frame(width: 76, height: 76)
    }

    @ViewBuilder
    private var imageContent: some View {
        if let remoteURLString = attachment.remoteURLString,
           let remoteURL = MHBBackendEndpoint.resolve(remoteURLString) {
            MHBRemoteImage(url: remoteURL, contentMode: .fill) {
                Image(uiImage: attachment.previewImage)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            Image(uiImage: attachment.previewImage)
                .resizable()
                .scaledToFill()
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch attachment.uploadState {
        case .uploading(let progress):
            ZStack {
                Color.black.opacity(0.34)
                ProgressView(value: min(max(progress, 0), 1))
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        case .failed:
            Button(action: onRetry) {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("重试")
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Color.black.opacity(0.48))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("重新上传照片")
        case .uploaded:
            EmptyView()
        }
    }
}
