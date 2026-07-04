
import SwiftUI
import MaohuobanDesignSystem

// PetQuickFactDetailScreen 快速事实详情页
// 核心职责：
// - 只展示便便正常、精神不错、食欲正常三类一次性快速事实
// - 通过后端事件详情和入口上下文展示真实宠物身份
// - 保持喂食、异常、体重、医疗照护和遛弯记录不进入此页面
struct PetQuickFactDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let recordID: String
    let kind: PetQuickFactDetailKind
    let currentUserID: String?
    let recordContext: PetRecordEntryContext

    @State private var store = PetEventDetailStore()
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        MHBScreenScrollView {
            switch store.phase {
            case .idle, .loading:
                PetQuickFactDetailLoadingView()
            case .failed(let message):
                PetQuickFactDetailErrorView(message: message)
            case .deleted:
                PetQuickFactDetailErrorView(message: "记录已删除")
            case .loaded(let event):
                PetQuickFactDetailContentView(
                    event: event,
                    kind: kind,
                    recordContext: recordContext
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("快速事实详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .loaded = store.phase {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(MHBTheme.ColorToken.danger.color)
                    }
                    .disabled(store.isMutating)
                    .accessibilityLabel("删除快速事实记录")
                }
            }
        }
        .alert("删除快速事实记录", isPresented: $isDeleteConfirmationPresented) {
            Button("删除记录", role: .destructive) {
                Task {
                    if await store.delete(eventID: recordID, currentUserID: currentUserID) {
                        dismiss()
                    }
                }
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除这条快速事实记录，删除后无法在时间线中查看。")
        }
        .task(id: recordID) {
            await store.load(eventID: recordID, currentUserID: currentUserID)
        }
        .accessibilityIdentifier("pet.quickFactDetail.screen")
    }
}

// PetQuickFactDetailLoadingView 快速事实加载态
// 核心职责：
// - 在事件详情请求期间展示轻量反馈
// - 避免详情页在未加载时展示占位业务数据
private struct PetQuickFactDetailLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载记录详情")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}

// PetQuickFactDetailErrorView 快速事实错误态
// 核心职责：
// - 展示事件详情加载失败原因
// - 阻止页面回落到本地演示数据
private struct PetQuickFactDetailErrorView: View {
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

// PetQuickFactDetailContentView 快速事实详情内容
// 核心职责：
// - 从事件详情构建展示模型
// - 展示快速事实回执内容
private struct PetQuickFactDetailContentView: View {
    let event: PetEventDetail
    let kind: PetQuickFactDetailKind
    let recordContext: PetRecordEntryContext

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            PetQuickFactReceiptCard(
                presentation: PetQuickFactDetailPresentation(
                    event: event,
                    kind: kind,
                    recordContext: recordContext
                )
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, MHBTheme.Spacing.s6)
        .padding(.bottom, MHBTheme.Spacing.s8)
    }
}

// PetQuickFactReceiptCard 快速事实小票卡片
// 核心职责：
// - 展示快速事实图标、标题、发生时间和关键字段
// - 让三类快速事实保持一致的轻量详情结构
private struct PetQuickFactReceiptCard: View {
    let presentation: PetQuickFactDetailPresentation

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 64, height: 64)
                .background(presentation.tint.opacity(0.10))
                .clipShape(Circle())
                .padding(.bottom, MHBTheme.Spacing.s5)

            Text(presentation.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s2)

            Text(presentation.timeText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .padding(.bottom, MHBTheme.Spacing.s8)

            PetQuickFactDashedDivider()
                .padding(.bottom, MHBTheme.Spacing.s5)

            VStack(spacing: 0) {
                ForEach(presentation.rows) { row in
                    PetQuickFactReceiptRow(row: row)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
        .accessibilityIdentifier("pet.quickFactDetail.receiptCard")
    }
}

// PetQuickFactReceiptRow 快速事实小票字段行
// 核心职责：
// - 展示单个字段和值
// - 支持宠物身份和普通文本两种字段值
private struct PetQuickFactReceiptRow: View {
    let row: PetQuickFactDetailPresentation.Row

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(row.title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            PetQuickFactReceiptRowValue(value: row.value)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}

// PetQuickFactReceiptRowValue 快速事实字段值
// 核心职责：
// - 渲染普通文本或宠物头像名称组合
// - 复用 MHBAvatar 保持头像基础设施一致
private struct PetQuickFactReceiptRowValue: View {
    let value: PetQuickFactDetailPresentation.RowValue

    var body: some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
        case .pet(let pet):
            HStack(spacing: MHBTheme.Spacing.s2) {
                MHBAvatar(
                    subject: .pet(
                        MHBAvatarPet(
                            id: pet.id,
                            name: pet.name,
                            source: pet.avatarSource,
                            species: .other,
                            sex: .unknown
                        )
                    ),
                    size: .custom(28),
                    shape: .circle
                )

                Text(pet.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
            }
        }
    }
}

// PetQuickFactDashedDivider 快速事实虚线分隔
// 核心职责：
// - 承载小票样式字段区分隔线
// - 避免引入图片或 UIKit 桥接
private struct PetQuickFactDashedDivider: View {
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
