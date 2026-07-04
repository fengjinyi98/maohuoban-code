import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailContentView 疫苗驱虫详情内容
// 核心职责：
// - 将真实事件详情转换为页面展示模型
// - 组合状态、信息、提醒和附件分区
struct PetPreventiveCareRecordDetailContentView: View {
    let event: PetEventDetail
    let fallbackKind: PetPreventiveCareKind
    let recordContext: PetRecordEntryContext

    private var presentation: PetPreventiveCareRecordDetailPresentation {
        PetPreventiveCareRecordDetailPresentation(
            event: event,
            recordContext: recordContext,
            fallbackKind: fallbackKind
        )
    }

    var body: some View {
        let presentation = presentation

        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            PetPreventiveCareRecordDetailHeader(presentation: presentation)
            PetPreventiveCareRecordStatusSection(presentation: presentation)
            PetPreventiveCareRecordInfoSection(rows: presentation.infoRows)
            PetPreventiveCareRecordReminderSection(rows: presentation.reminderRows)
            PetPreventiveCareRecordEvidenceSection(
                note: presentation.note,
                attachmentAssetIDs: presentation.attachmentAssetIDs
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, MHBTheme.Spacing.s6)
        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
    }
}
