import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailScreen 疫苗驱虫记录详情页
// 核心职责：
// - 从后端事件详情加载单条疫苗或驱虫记录
// - 承载编辑和删除操作并回写上层列表
struct PetPreventiveCareRecordDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let recordID: String
    let fallbackKind: PetPreventiveCareKind
    let currentUserID: String?
    let recordContext: PetRecordEntryContext
    var onDeleted: (String) -> Void = { _ in }

    @State private var detailStore = PetEventDetailStore()
    @State private var mutationStore = PetPreventiveCareStore()
    @State private var isDeleteConfirmationPresented = false
    @State private var formMode: PetPreventiveCareFormMode?

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    switch detailStore.phase {
                    case .idle, .loading:
                        PetPreventiveCareRecordDetailLoadingView()
                    case .failed(let message):
                        PetPreventiveCareRecordDetailErrorView(message: message)
                    case .deleted:
                        PetPreventiveCareRecordDetailErrorView(message: "记录已删除")
                    case .loaded(let event):
                        PetPreventiveCareRecordDetailContentView(
                            event: event,
                            fallbackKind: fallbackKind,
                            recordContext: recordContext
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                if case .loaded(let event) = detailStore.phase,
                   let editRecord = PetPreventiveCareRecordMapper.record(from: event) {
                    MHBBottomFloatingActionCTA(
                        title: "修改记录信息",
                        systemImage: "pencil",
                        bottomInset: bottomInset,
                        action: {
                            formMode = .edit(editRecord)
                        }
                    )
                    .zIndex(2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .loaded = detailStore.phase {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    }
                    .disabled(detailStore.isMutating || mutationStore.isMutating)
                    .accessibilityLabel("删除\(fallbackKind.recordTitle)")
                }
            }
        }
        .alert("删除\(fallbackKind.recordTitle)", isPresented: $isDeleteConfirmationPresented) {
            Button("删除记录", role: .destructive) {
                Task {
                    if await detailStore.delete(eventID: recordID, currentUserID: currentUserID) {
                        onDeleted(recordID)
                        dismiss()
                    }
                }
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除这条\(fallbackKind.recordTitle)，删除后无法在预防护理记录中查看。")
        }
        .sheet(item: $formMode) { mode in
            PetPreventiveCareAddRecordSheet(
                mode: mode,
                currentUserID: currentUserID,
                isSubmitting: mutationStore.isMutating,
                onSave: saveRecord(mode:draft:)
            )
        }
        .task(id: recordID) {
            await detailStore.load(eventID: recordID, currentUserID: currentUserID)
        }
        .accessibilityIdentifier("pet.preventiveCareRecordDetail.screen")
    }

    private var navigationTitle: String {
        switch detailStore.phase {
        case .loaded(let event):
            PetPreventiveCareRecordDetailPresentation(
                event: event,
                recordContext: recordContext,
                fallbackKind: fallbackKind
            ).navigationTitle
        default:
            "\(fallbackKind.recordTitle)详情"
        }
    }

    private func saveRecord(mode: PetPreventiveCareFormMode, draft: PetPreventiveCareDraft) {
        Task {
            guard await mutationStore.update(
                eventID: recordID,
                petID: recordContext.resolvedPetID,
                currentUserID: currentUserID,
                draft: draft
            ) else { return }
            formMode = nil
            await detailStore.load(eventID: recordID, currentUserID: currentUserID)
        }
    }
}
