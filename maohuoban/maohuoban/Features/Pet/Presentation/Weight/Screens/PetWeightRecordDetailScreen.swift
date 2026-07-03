import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordDetailScreen 单条体重记录详情页
// 核心职责：
// - 展示单次体重记录的宠物、体重、变化和备注
// - 与快速事实详情保持小票式详情结构
// - 区分体重总览页和单条记录详情页的产品边界
struct PetWeightRecordDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let recordID: String
    let petName: String
    let petAvatarSubject: MHBAvatarSubject?
    let store: PetWeightRecordStore

    @State private var isEditSheetPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .bottom) {
                MHBScreenScrollView {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                        if let record {
                            let presentation = PetWeightRecordDetailPresentation(
                                record: record,
                                petName: petName,
                                petAvatarSubject: petAvatarSubject,
                                records: store.records
                            )
                            PetWeightRecordReceiptCard(presentation: presentation)
                            PetWeightRecordNearbySection(records: presentation.nearbyRecords)
                        } else {
                            PetWeightRecordMissingState()
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                }
                .frame(maxWidth: .infinity)

                if record != nil {
                    MHBBottomFloatingActionCTA(
                        title: "修改记录信息",
                        systemImage: "pencil",
                        bottomInset: bottomInset,
                        action: {
                            isEditSheetPresented = true
                        }
                    )
                    .zIndex(2)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("体重记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if record != nil {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    }
                    .accessibilityLabel("删除体重记录")
                }
            }
        }
        .sheet(isPresented: $isEditSheetPresented) {
            if let record {
                PetWeightRecordSheet(
                    petName: petName,
                    initialWeightText: record.weightText,
                    mode: .edit(record),
                    onSave: { draft in
                        await store.update(recordID: record.id, draft: draft)
                    }
                )
            }
        }
        .alert("删除体重记录", isPresented: $isDeleteConfirmationPresented) {
            Button("删除记录", role: .destructive) {
                Task {
                    if await store.delete(recordID: recordID) {
                        dismiss()
                    }
                }
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除这条体重记录，删除后无法在体重趋势中查看。")
        }
        .accessibilityIdentifier("pet.weightRecordDetail.screen")
    }

    private var record: PetWeightRecord? {
        store.record(id: recordID)
    }
}

// PetWeightRecordReceiptCard 体重记录小票卡片
// 核心职责：
// - 突出展示本次体重数值和变化
// - 展示单条记录的关键字段
private struct PetWeightRecordReceiptCard: View {
    let presentation: PetWeightRecordDetailPresentation

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            MHBAvatar(
                subject: presentation.petAvatarSubject,
                size: .large,
                shape: .circle
            )
                .padding(.bottom, MHBTheme.Spacing.s5)

            Text("体重记录")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s2)

            Text(presentation.timeText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s5)

            HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s1) {
                Text(presentation.weightText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text("kg")
                    .font(MHBTheme.Typography.title.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .padding(.bottom, MHBTheme.Spacing.s2)

            PetWeightRecordDeltaTag(
                text: presentation.deltaText,
                kind: presentation.deltaKind
            )
            .padding(.bottom, MHBTheme.Spacing.s6)

            PetWeightRecordDashedDivider()
                .padding(.bottom, MHBTheme.Spacing.s5)

            VStack(spacing: 0) {
                ForEach(presentation.rows) { row in
                    PetWeightRecordReceiptRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
        .accessibilityIdentifier("pet.weightRecordDetail.receiptCard")
    }
}

// PetWeightRecordDeltaTag 体重变化标签
// 核心职责：
// - 展示本次记录相对上次的变化
// - 使用趋势颜色帮助用户快速判断方向
private struct PetWeightRecordDeltaTag: View {
    let text: String
    let kind: PetWeightRecordDetailPresentation.DeltaKind

    var body: some View {
        Label(text, systemImage: kind.systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(kind.color)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .padding(.vertical, MHBTheme.Spacing.s2)
            .background(kind.color.opacity(0.12), in: Capsule())
    }
}

// PetWeightRecordReceiptRow 体重记录字段行
// 核心职责：
// - 展示体重详情里的单项字段和值
// - 支持宠物头像名称和普通文本两种展示
private struct PetWeightRecordReceiptRow: View {
    let row: PetWeightRecordDetailPresentation.Row

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(row.title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            PetWeightRecordReceiptRowValue(value: row.value)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetWeightRecordReceiptRowValue 体重记录字段值
// 核心职责：
// - 渲染普通文本或宠物身份组合
// - 复用头像基础设施保持记录详情一致
private struct PetWeightRecordReceiptRowValue: View {
    let value: PetWeightRecordDetailPresentation.RowValue

    var body: some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
        }
    }
}

// PetWeightRecordNearbySection 体重相邻记录区
// 核心职责：
// - 展示本次记录附近的体重上下文
// - 帮助用户判断单次体重变化是否明显
private struct PetWeightRecordNearbySection: View {
    let records: [PetWeightRecordDetailPresentation.NearbyRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("附近记录")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            VStack(spacing: 0) {
                ForEach(records) { record in
                    PetWeightRecordNearbyRow(record: record)

                    if record.id != records.last?.id {
                        Rectangle()
                            .fill(MHBTheme.ColorToken.separatorSoft.color)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
        }
    }
}

// PetWeightRecordNearbyRow 附近体重记录行
// 核心职责：
// - 展示相邻体重记录的日期、备注和数值
// - 标记当前正在查看的记录
private struct PetWeightRecordNearbyRow: View {
    let record: PetWeightRecordDetailPresentation.NearbyRecord

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(record.dateText)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.note)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s3)

            VStack(alignment: .trailing, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(record.weightText)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                if record.isCurrent {
                    Text("当前")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// PetWeightRecordMissingState 体重记录缺失状态
// 核心职责：
// - 在记录被删除或未加载时给出轻量反馈
// - 避免详情页继续展示过期 mock 数据
private struct PetWeightRecordMissingState: View {
    var body: some View {
        Text("这条体重记录暂时不可用")
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, minHeight: 220)
            .multilineTextAlignment(.center)
    }
}

// PetWeightRecordDashedDivider 体重记录虚线分隔
// 核心职责：
// - 承载小票样式字段区分隔线
// - 保持单条记录详情的视觉节奏
private struct PetWeightRecordDashedDivider: View {
    var body: some View {
        Line()
            .stroke(
                MHBTheme.ColorToken.separator.color,
                style: StrokeStyle(lineWidth: 1, dash: [5, 5])
            )
            .frame(height: 1)
    }

    private struct Line: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
