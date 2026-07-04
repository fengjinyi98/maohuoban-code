import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordEvidenceSection 疫苗驱虫备注与照片区
// 核心职责：
// - 展示用户备注和记录凭证
// - 使用真实事件附件资产渲染照片
struct PetPreventiveCareRecordEvidenceSection: View {
    let note: String
    let attachmentAssetIDs: [String]

    var body: some View {
        PetPreventiveCareRecordDetailSection(title: "备注与照片") {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                Text(note)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)

                if !attachmentAssetIDs.isEmpty {
                    PetEventAttachmentDisplayGallery(assetIDs: attachmentAssetIDs)
                }
            }
        }
    }
}
