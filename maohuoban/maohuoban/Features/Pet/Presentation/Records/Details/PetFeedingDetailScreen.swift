import SwiftUI
import MaohuobanDesignSystem

// PetFeedingDetailScreen 喂食记录详情页
// 核心职责：
// - 展示单条喂食记录的宠物、份量、食品、备注和照片
// - 通过 PetEventDetailStore 加载后端事件详情
// - 使用少量、正常、多一点等低摩擦份量语义
// - 避免展示克数、进食方式和记录来源等当前产品边界外字段
struct PetFeedingDetailScreen: View {
    @Environment(\.dismiss) private var dismiss

    let recordID: String
    let currentUserID: String?
    let recordContext: PetRecordEntryContext
    var onDeleted: (String) -> Void = { _ in }

    @State private var store = PetEventDetailStore()
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        MHBScreenScrollView {
            switch store.phase {
            case .idle, .loading:
                PetFeedingDetailLoadingView()
            case .failed(let message):
                PetFeedingDetailErrorView(message: message)
            case .deleted:
                PetFeedingDetailErrorView(message: "记录已删除")
            case .loaded(let event):
                PetFeedingDetailContentView(
                    event: event,
                    recordContext: recordContext
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("喂食详情")
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
                    .accessibilityLabel("删除喂食记录")
                }
            }
        }
        .alert("删除喂食记录", isPresented: $isDeleteConfirmationPresented) {
            Button("删除记录", role: .destructive) {
                Task {
                    if await store.delete(eventID: recordID, currentUserID: currentUserID) {
                        onDeleted(recordID)
                        dismiss()
                    }
                }
            }

            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除这条喂食记录，删除后无法在时间线中查看。")
        }
        .task(id: recordID) {
            await store.load(eventID: recordID, currentUserID: currentUserID)
        }
        .accessibilityIdentifier("pet.feedingDetail.screen")
    }
}

// PetFeedingDetailLoadingView 喂食详情加载态
// 核心职责：
// - 在后端事件详情请求期间展示反馈
// - 避免页面未加载时出现演示数据
private struct PetFeedingDetailLoadingView: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载喂食详情")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}

// PetFeedingDetailErrorView 喂食详情错误态
// 核心职责：
// - 展示事件详情加载失败原因
// - 阻止详情页回落到本地展示数据
private struct PetFeedingDetailErrorView: View {
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

// PetFeedingDetailContentView 喂食详情内容
// 核心职责：
// - 将后端事件详情转换为展示模型
// - 组合喂食数据、关联食品和备注照片分区
private struct PetFeedingDetailContentView: View {
    let event: PetEventDetail
    let recordContext: PetRecordEntryContext

    private var presentation: PetFeedingDetailPresentation {
        PetFeedingDetailPresentation(event: event, recordContext: recordContext)
    }

    var body: some View {
        let presentation = presentation

        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            PetFeedingDetailHeader(presentation: presentation)
            PetFeedingDataSection(amountText: presentation.amountText)
            PetFeedingFoodSection(food: presentation.food)
            PetFeedingEvidenceSection(
                note: presentation.note,
                attachmentAssetIDs: presentation.attachmentAssetIDs
            )
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, MHBTheme.Spacing.s6)
        .padding(.bottom, MHBTheme.Spacing.s8)
    }
}

// PetFeedingDetailHeader 喂食详情头部
// 核心职责：
// - 展示喂食事件状态、宠物头像名称和发生时间
// - 让用户快速确认记录归属
private struct PetFeedingDetailHeader: View {
    let presentation: PetFeedingDetailPresentation

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "fork.knife")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(mhbHex: "0093DD"))
                .frame(width: 56, height: 56)
                .background(Color(mhbHex: "0093DD").opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(presentation.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    MHBAvatar(
                        subject: .pet(presentation.pet.avatarPet),
                        size: .custom(24),
                        shape: .circle
                    )

                    Text("\(presentation.pet.name) · \(presentation.timeText)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}

// PetFeedingDataSection 喂食数据分组
// 核心职责：
// - 展示低摩擦份量描述
// - 避免使用克数作为主要记录方式
private struct PetFeedingDataSection: View {
    let amountText: String

    var body: some View {
        PetFeedingDetailSection(title: "喂食数据") {
            PetFeedingDetailInfoRow(title: "份量", value: amountText)
        }
    }
}

// PetFeedingFoodSection 关联食品分组
// 核心职责：
// - 展示本次喂食关联的储物柜食品
// - 保留食品图片、名称和规格信息
private struct PetFeedingFoodSection: View {
    let food: PetFeedingDetailPresentation.Food

    var body: some View {
        PetFeedingDetailSection(title: "关联食品") {
            HStack(spacing: MHBTheme.Spacing.s3) {
                PetFeedingFoodThumbnail(
                    imageURLString: food.imageURLString,
                    systemImage: food.systemImage
                )

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(food.name)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(food.subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)
            }
        }
    }
}

// PetFeedingEvidenceSection 喂食备注与照片分组
// 核心职责：
// - 展示用户补充备注
// - 展示本次喂食可选照片
private struct PetFeedingEvidenceSection: View {
    let note: String
    let attachmentAssetIDs: [String]

    var body: some View {
        PetFeedingDetailSection(title: "备注与照片") {
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

// PetFeedingDetailSection 喂食详情分组容器
// 核心职责：
// - 统一喂食详情分组标题和卡片样式
// - 复用主题 token 保持页面一致性
private struct PetFeedingDetailSection<Content: View>: View {
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

// PetFeedingDetailInfoRow 喂食详情信息行
// 核心职责：
// - 展示单项键值信息
// - 保持左右可扫描布局
private struct PetFeedingDetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .frame(minHeight: 44)
    }
}

// PetFeedingFoodThumbnail 喂食食品缩略图
// 核心职责：
// - 展示关联食品远程图片
// - 在缺少图片时使用食品类别图标兜底
private struct PetFeedingFoodThumbnail: View {
    let imageURLString: String?
    let systemImage: String

    var body: some View {
        Group {
            if let imageURLString,
               let imageURL = MHBBackendEndpoint.resolve(imageURLString) {
                MHBRemoteImage(url: imageURL, contentMode: .fill) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }

    private var placeholder: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color(mhbHex: "0093DD"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(mhbHex: "0093DD").opacity(0.10))
    }
}
