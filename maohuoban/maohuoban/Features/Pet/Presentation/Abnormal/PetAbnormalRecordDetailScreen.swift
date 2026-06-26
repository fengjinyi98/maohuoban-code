import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordDetailScreen 异常记录详情页
// 核心职责：
// - 展示单条异常记录的宠物、异常项、程度、备注
// - 通过 PetAbnormalDetailStore 从后端加载真实事件详情
// - 提供追加观察和标记恢复的命令式入口
// - 不展示 AI/LLM 建议，避免主动记录详情与智能建议混淆
struct PetAbnormalRecordDetailScreen: View {
    let recordID: String
    let currentUserID: String?

    @State private var store = PetAbnormalDetailStore()
    @State private var presentedSheet: PetAbnormalRecordDetailSheet?
    @State private var observationNote = ""
    @State private var recoveryNote = ""

    var body: some View {
        MHBScreenScrollView {
            switch store.phase {
            case .idle, .loading:
                PetAbnormalDetailLoadingView()
            case .failed(let message):
                PetAbnormalDetailErrorView(message: message)
            case .loaded(let event):
                PetAbnormalDetailContentView(
                    event: event,
                    store: store,
                    onSelectAction: { action in
                        presentedSheet = .action(action)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("异常详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load(eventID: recordID, currentUserID: currentUserID)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .action(let action):
                PetAbnormalRecordActionSheet(
                    action: action,
                    store: store,
                    observationNote: $observationNote,
                    recoveryNote: $recoveryNote,
                    petID: currentPetID,
                    currentUserID: currentUserID
                )
            case .relatedRecord(let record):
                PetAbnormalRecordRelatedRecordSheet(record: record)
            }
        }
        .onChange(of: store.actionPhase) { _, newValue in
            if case .succeeded = newValue {
                presentedSheet = nil
                observationNote = ""
                recoveryNote = ""
                Task {
                    await store.load(eventID: recordID, currentUserID: currentUserID)
                }
            }
        }
        .accessibilityIdentifier("pet.abnormalRecordDetail.screen")
    }

    private var currentPetID: String? {
        guard case .loaded(let event) = store.phase else { return nil }
        return event.petID
    }
}

// PetAbnormalDetailLoadingView 异常详情加载态
private struct PetAbnormalDetailLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载异常详情")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}

// PetAbnormalDetailErrorView 异常详情错误态
private struct PetAbnormalDetailErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}

// PetAbnormalDetailContentView 异常详情内容
// 核心职责：
// - 将 PetEventDetail 映射为展示模型
// - 组合头部、症状、备注和操作入口
private struct PetAbnormalDetailContentView: View {
    let event: PetEventDetail
    let store: PetAbnormalDetailStore
    let onSelectAction: (PetAbnormalRecordDetailAction) -> Void

    private var payload: PetEventDetailPayload? {
        event.eventPayload
    }

    private var severity: PetAbnormalSeverity? {
        guard let raw = payload?.severity else { return nil }
        return PetAbnormalSeverity(rawValue: raw)
    }

    private var symptoms: [PetAbnormalSymptom] {
        guard let kinds = payload?.symptomKinds else { return [] }
        return kinds.compactMap { PetAbnormalSymptom(rawValue: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            PetAbnormalRecordDetailHeader(
                title: event.title,
                timeText: event.occurredAt,
                severity: severity
            )

            if !symptoms.isEmpty {
                PetAbnormalRecordSymptomSection(
                    symptoms: symptoms,
                    tint: tint
                )
            }

            if let details = payload?.symptomDetails, !details.isEmpty {
                PetAbnormalRecordObservationSection(details: details)
            }

            if let note = payload?.note, !note.isEmpty {
                PetAbnormalRecordEvidenceSection(note: note)
            }

            if let summary = event.summary, !summary.isEmpty {
                PetAbnormalRecordDetailSection(title: "摘要") {
                    Text(summary)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            PetAbnormalRecordEpisodeActions(
                onSelectAction: onSelectAction
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, MHBTheme.Spacing.s6)
        .padding(.bottom, MHBTheme.Spacing.s8)
    }

    private var tint: Color {
        severity?.tint ?? MHBTheme.ColorToken.warning.color
    }
}

// PetAbnormalRecordDetailHeader 异常详情头部
// 核心职责：
// - 展示异常记录标题、发生时间和严重程度
private struct PetAbnormalRecordDetailHeader: View {
    let title: String
    let timeText: String
    let severity: PetAbnormalSeverity?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack(spacing: MHBTheme.Spacing.s4) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 56)
                    .background(tint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text(timeText)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)
            }

            if let severity {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                    Text(severity.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.vertical, MHBTheme.Spacing.s2)
                        .background(tint.opacity(0.12), in: Capsule())

                    Text(severity.subtitle)
                        .font(MHBTheme.Typography.callout)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }

    private var tint: Color {
        severity?.tint ?? MHBTheme.ColorToken.warning.color
    }
}

// PetAbnormalRecordSymptomSection 异常项分组
// 核心职责：
// - 展示本次记录涉及的异常类型
private struct PetAbnormalRecordSymptomSection: View {
    let symptoms: [PetAbnormalSymptom]
    let tint: Color

    var body: some View {
        PetAbnormalRecordDetailSection(title: "异常项") {
            MHBFlowLayout(
                horizontalSpacing: MHBTheme.Spacing.s2,
                verticalSpacing: MHBTheme.Spacing.s2
            ) {
                ForEach(symptoms) { symptom in
                    Label(symptom.title, systemImage: symptom.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.vertical, MHBTheme.Spacing.s2)
                        .background(tint.opacity(0.10), in: Capsule())
                }
            }
        }
    }
}

// PetAbnormalRecordObservationSection 具体表现分组
// 核心职责：
// - 展示异常记录里的细分表现
private struct PetAbnormalRecordObservationSection: View {
    let details: [String]

    var body: some View {
        PetAbnormalRecordDetailSection(title: "具体表现") {
            VStack(spacing: 0) {
                ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                    PetAbnormalRecordInfoRow(
                        title: "表现",
                        value: detail
                    )

                    if detail != details.last {
                        Rectangle()
                            .fill(MHBTheme.ColorToken.separatorSoft.color)
                            .frame(height: 1)
                    }
                }
            }
        }
    }
}

// PetAbnormalRecordEvidenceSection 异常备注分组
// 核心职责：
// - 展示用户补充描述
private struct PetAbnormalRecordEvidenceSection: View {
    let note: String

    var body: some View {
        PetAbnormalRecordDetailSection(title: "备注") {
            Text(note)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// PetAbnormalRecordDetailSection 异常详情分组容器
// 核心职责：
// - 统一异常详情分组标题和卡片样式
// - 复用主题 token 保持详情页一致性
struct PetAbnormalRecordDetailSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
        }
    }
}

// PetAbnormalRecordInfoRow 异常详情信息行
private struct PetAbnormalRecordInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetAbnormalSeverity tint 扩展
private extension PetAbnormalSeverity {
    var tint: Color {
        switch self {
        case .mild:
            MHBTheme.ColorToken.primary.color
        case .obvious:
            MHBTheme.ColorToken.warning.color
        case .severe:
            MHBTheme.ColorToken.danger.color
        }
    }
}
