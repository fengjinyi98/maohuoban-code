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

// MerchantAvailableStatusLoadingSection 可售发布加载态
// 核心职责：
// - 展示候选宠物加载过程
// - 保持首屏结构稳定
private struct MerchantAvailableStatusLoadingSection: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在读取待发布宠物")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.availableStatus.loading")
    }
}

// MerchantAvailableStatusFormSection 可售发布表单
// 核心职责：
// - 收集发布对象和买家可见摘要
// - 将提交事件转发给页面动作
private struct MerchantAvailableStatusFormSection: View {
    let pets: [MerchantManagedPet]
    @Binding var selectedPetID: String
    @Binding var summary: String
    let isSubmitting: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            MerchantAvailableStatusIntroCard(count: pets.count)

            if pets.isEmpty {
                MerchantAvailableStatusEmptySection()
            } else {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                    Text("发布对象")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    Picker("发布对象", selection: $selectedPetID) {
                        ForEach(pets) { pet in
                            Text(pet.name).tag(pet.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(MHBTheme.Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MHBTheme.ColorToken.cardSolid.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .accessibilityIdentifier("merchant.availableStatus.petPicker")

                    Text("买家可见摘要")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    TextField("买家可见摘要", text: $summary, axis: .vertical)
                        .lineLimit(3...5)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .padding(MHBTheme.Spacing.s3)
                        .background(MHBTheme.ColorToken.cardSolid.color)
                        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                        .accessibilityIdentifier("merchant.availableStatus.summaryInput")

                    Button(action: onSubmit) {
                        Label("发布可售状态", systemImage: "tag.fill")
                            .font(MHBTheme.Typography.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedPetID.isEmpty || isSubmitting)
                    .accessibilityIdentifier("merchant.availableStatus.submit")
                }
                .padding(MHBTheme.Spacing.s4)
                .background(MHBTheme.ColorToken.card.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            }
        }
    }
}

// MerchantAvailableStatusIntroCard 可售发布说明卡
// 核心职责：
// - 展示当前待发布数量
// - 提示发布会同步写入事件账本
private struct MerchantAvailableStatusIntroCard: View {
    let count: Int

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "tag.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("买家可见状态")
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text("发布后会更新宠物经营状态，并追加一条商家事件记录")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer()

            Text("\(count)")
                .font(MHBTheme.Typography.largeTitle)
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// MerchantAvailableStatusEmptySection 可售发布空态
// 核心职责：
// - 展示没有待发布宠物的状态
// - 引导商家先补充宠物记录
private struct MerchantAvailableStatusEmptySection: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.success.color)
            Text("暂无待发布宠物")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text("需要先补齐基础记录，再发布买家可见状态")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.availableStatus.empty")
    }
}

// MerchantAvailableStatusPublishingSection 可售发布提交态
// 核心职责：
// - 展示发布请求处理中状态
// - 避免重复提交造成多条事件
private struct MerchantAvailableStatusPublishingSection: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在发布可售状态")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.availableStatus.publishing")
    }
}

// MerchantAvailableStatusPublishedSection 可售发布成功态
// 核心职责：
// - 展示发布后的宠物和事件摘要
// - 让商家确认状态已进入买家可见时间线
private struct MerchantAvailableStatusPublishedSection: View {
    let publication: MerchantAvailableStatusPublication

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Label("可售状态已发布", systemImage: "checkmark.seal.fill")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.success.color)

            Text(publication.pet.name)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(publication.event.summary ?? "已同步写入买家可见时间线")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.availableStatus.published")
    }
}

// MerchantAvailableStatusFailedSection 可售发布失败态
// 核心职责：
// - 展示候选加载或发布失败原因
// - 保持错误反馈在当前页面内呈现
private struct MerchantAvailableStatusFailedSection: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
            Text("暂时无法发布可售状态")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("merchant.availableStatus.failed")
    }
}
