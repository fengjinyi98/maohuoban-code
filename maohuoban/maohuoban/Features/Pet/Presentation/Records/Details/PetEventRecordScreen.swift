import SwiftUI
import MaohuobanDesignSystem

// PetEventRecordScreen 宠物事件记录页面
// 核心职责：
// - 收集当前宠物的一条健康记录
// - 通过 PetWriteStore 调用宠物事件追加接口
struct PetEventRecordScreen: View {
    let petID: String?
    let petSex: PetRecordPetSex
    let lifeStatus: String?
    let currentUserID: String?
    let mode: PetEventRecordMode
    let onRecorded: () -> Void

    @State private var store = PetWriteStore()
    @State private var title: String
    @State private var summary = ""
    @State private var occurredAt = Date()
    @State private var selectedHealthType = PetHealthRecordType.vaccine
    @State private var healthVaccineBrand = ""
    @State private var healthVaccineDose = ""
    @State private var healthVisitReason = ""
    @State private var healthNote = ""
    @State private var healthReminderEnabled = true
    @State private var healthReminderDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    init(
        petID: String?,
        petSex: PetRecordPetSex = .unknown,
        lifeStatus: String? = nil,
        currentUserID: String?,
        mode: PetEventRecordMode,
        onRecorded: @escaping () -> Void
    ) {
        self.petID = petID
        self.petSex = petSex
        self.lifeStatus = lifeStatus
        self.currentUserID = currentUserID
        self.mode = mode
        self.onRecorded = onRecorded
        self._title = State(initialValue: mode.defaultTitle)
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                PetWriteStatusSection(
                    phase: store.phase,
                    successMessage: store.successMessage
                )

                if petID == nil {
                    PetRecordUnavailableSection()
                } else {
                    recordFields
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(mode.submitTitle) {
                    Task { await submit() }
                }
                .font(MHBTheme.Typography.headline)
                .disabled(store.isSubmitting || petID == nil)
            }
        }
        .petWriteToastBridge(
            phase: store.phase,
            successMessage: store.successMessage
        )
        .accessibilityIdentifier("pet.eventRecord.screen")
    }

    @ViewBuilder
    private var recordFields: some View {
        switch mode {
        case .health:
            PetHealthRecordContent(
                petID: petID,
                petSex: petSex,
                selectedType: $selectedHealthType,
                occurredAt: $occurredAt,
                vaccineBrand: $healthVaccineBrand,
                vaccineDose: $healthVaccineDose,
                visitReason: $healthVisitReason,
                note: $healthNote,
                reminderEnabled: $healthReminderEnabled,
                reminderDate: $healthReminderDate
            )
        }
    }

    // submit 提交宠物事件
    // 核心职责：
    // - 将表单状态转换为事件草稿
    // - 成功后通知首页刷新聚合快照
    private func submit() async {
        let eventDraft = makeEventDraft()
        await store.createEvent(
            petID: petID,
            draft: eventDraft,
            currentUserID: currentUserID,
            lifeStatus: lifeStatus
        )
        if case .recordedEvent = store.phase {
            onRecorded()
        }
    }

    private func makeEventDraft() -> PetEventDraft {
        switch mode {
        case .health:
            let healthDraft = PetHealthRecordFormDraft(
                type: selectedHealthType,
                weightText: "",
                vaccineBrand: healthVaccineBrand,
                vaccineDose: healthVaccineDose,
                visitReason: healthVisitReason,
                note: healthNote,
                reminderEnabled: healthReminderEnabled,
                reminderDateText: reminderDateText
            )
            return PetEventDraft(
                kind: mode.eventKind,
                subkind: healthDraft.eventSubkind,
                title: healthDraft.eventTitle,
                summary: healthDraft.eventSummary,
                visibility: .private,
                occurredAt: PetWriteFormatters.occurredAtString(from: occurredAt)
            )
        }
    }

    private var reminderDateText: String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: healthReminderDate)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

}

// PetEventRecordMode 宠物事件记录模式
// 核心职责：
// - 承载首页健康记录入口的事件底座映射
// - 日常记录入口已由底部快捷记录和专项 sheet 接管
// - 将入口语义映射到事件底座字段
enum PetEventRecordMode: Equatable {
    case health

    var eventKind: PetEventKind {
        switch self {
        case .health: .health
        }
    }

    var subkind: String {
        switch self {
        case .health: "health"
        }
    }

    var defaultTitle: String {
        switch self {
        case .health: "健康记录"
        }
    }

    var navigationTitle: LocalizedStringResource {
        switch self {
        case .health: "健康记录"
        }
    }

    var submitTitle: LocalizedStringResource {
        switch self {
        case .health: "保存"
        }
    }
}

// PetEventRecordFields 宠物事件记录表单
// 核心职责：
// - 收集事件标题、摘要和发生时间
// - 保持表单输入与提交逻辑解耦
private struct PetEventRecordFields: View {
    let mode: PetEventRecordMode
    @Binding var title: String
    @Binding var summary: String
    @Binding var occurredAt: Date

    var body: some View {
        PetWriteFormSection(title: mode.navigationTitle) {
            PetWriteTextField(title: "标题", text: $title, prompt: "例如 体重记录")
                .accessibilityIdentifier("pet.event.titleInput")

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text("摘要")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                TextField("摘要", text: $summary, prompt: Text("例如 5.2kg，较上次稳定"), axis: .vertical)
                    .lineLimit(3...5)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .padding(MHBTheme.Spacing.s3)
                    .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    .accessibilityIdentifier("pet.event.summaryInput")
            }

            DatePicker(
                "发生时间",
                selection: $occurredAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}

// PetRecordUnavailableSection 记录不可用提示
// 核心职责：
// - 展示缺少当前宠物上下文时的页面状态
// - 阻止无宠物事件写入
private struct PetRecordUnavailableSection: View {
    var body: some View {
        PetWriteFormSection(title: "无法记录") {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "pawprint.circle")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                Text("请先创建或选择一只宠物")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }
        }
    }
}
