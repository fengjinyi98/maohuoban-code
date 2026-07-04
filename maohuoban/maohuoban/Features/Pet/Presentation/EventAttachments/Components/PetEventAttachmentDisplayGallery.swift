import SwiftUI
import MaohuobanDesignSystem

// PetEventAttachmentDisplayGallery 事件附件展示网格
// 核心职责：
// - 根据后端事件附件资产 ID 渲染真实上传图片
// - 为喂食和异常详情页提供一致的附件缩略图布局
struct PetEventAttachmentDisplayGallery: View {
    let assetIDs: [String]
    var thumbnailSize: CGFloat = 86

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(assetIDs, id: \.self) { assetID in
                MHBRemoteImage(
                    url: attachmentURL(assetID: assetID),
                    contentMode: .fill
                ) {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                }
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
            }
        }
    }

    private func attachmentURL(assetID: String) -> URL? {
        MHBBackendEndpoint.resolve("/api/v1/media/assets/\(assetID)/content")
    }
}
