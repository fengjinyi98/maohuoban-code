import SwiftUI
import MaohuobanDesignSystem

// MerchantAvailableStatusScreen 商家可售状态发布页
// 核心职责：
// - 展示待补记录宠物候选并收集买家可见摘要
// - 通过 MerchantAvailableStatusStore 发布可售状态和事件账本记录
struct MerchantAvailableStatusScreen: View {
    let merchantID: String
    let currentUserID: String?
    let onPublished: () -> Void

    @State private var store = MerchantAvailableStatusStore()
    @State private var selectedPetID = ""
    @State private var summary = "已完成基础健康记录，可预约到店看宠。"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                switch store.phase {
                case .idle, .loading:
                    MerchantAvailableStatusLoadingSection()
                case .loaded(let pets):
                    MerchantAvailableStatusFormSection(
                        pets: pets,
                        selectedPetID: $selectedPetID,
                        summary: $summary,
                        isSubmitting: store.isBusy
                    ) {
                        Task { await publish() }
                    }
                case .publishing:
                    MerchantAvailableStatusPublishingSection()
                case .published(let publication):
                    MerchantAvailableStatusPublishedSection(publication: publication)
                case .failed(let message):
                    MerchantAvailableStatusFailedSection(message: message)
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("发布可售状态")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskID) {
            await store.loadCandidates(merchantID: merchantID, currentUserID: currentUserID)
            selectFirstCandidateIfNeeded()
        }
        .accessibilityIdentifier("merchant.availableStatus.screen")
    }

    private var taskID: String {
        "\(merchantID)-\(currentUserID ?? "anonymous")"
    }

    // publish 发布可售状态
    // 核心职责：
    // - 将表单输入转换为发布草稿
    // - 成功后通知首页刷新聚合快照
    private func publish() async {
        await store.publish(
            merchantID: merchantID,
            petID: selectedPetID,
            draft: MerchantAvailableStatusDraft(
                summary: summary,
                occurredAt: currentTimestamp()
            ),
            currentUserID: currentUserID
        )
        if case .published = store.phase {
            onPublished()
        }
    }

    private func selectFirstCandidateIfNeeded() {
        guard selectedPetID.isEmpty else { return }
        guard case .loaded(let pets) = store.phase else { return }
        selectedPetID = pets.first?.id ?? ""
    }

    private func currentTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
