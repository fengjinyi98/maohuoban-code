import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordDetailScreen 病历记录详情页
// 核心职责：
// - 展示单条病历的就诊、诊断、处置和附件信息
// - 通过底部 CTA 进入追加记录表单
struct PetMedicalRecordDetailScreen: View {
    @Binding var record: PetMedicalRecord
    let onAppendUpdate: (PetMedicalRecord.Update) -> Void

    @State private var isAppendSheetPresented = false

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                        PetMedicalRecordDetailHeader(record: record)
                        PetMedicalRecordDetailInfoSection(record: record)
                        PetMedicalRecordAttachmentSection(titles: record.attachmentTitles)
                        PetMedicalRecordUpdateSection(updates: record.updates)
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                }
                .frame(maxWidth: .infinity)

                MHBBottomFloatingActionCTA(
                    title: "追加病历",
                    systemImage: "plus",
                    bottomInset: bottomInset,
                    action: {
                        isAppendSheetPresented = true
                    }
                )
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("病历详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAppendSheetPresented) {
            PetMedicalRecordFormSheet(
                mode: .append,
                onSave: { draft in
                    onAppendUpdate(draft.makeUpdate())
                }
            )
        }
        .accessibilityIdentifier("pet.medicalRecord.detail")
    }
}
