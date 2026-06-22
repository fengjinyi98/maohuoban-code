import SwiftUI
import MaohuobanDesignSystem

// SameCityCommodityGrowthRecordScreen 商品成长档案全屏页
// 核心职责：
// - 展示商品导入的宠物成长记录
// - 复刻设计稿中的摘要、时间轴和图片网格内容结构
struct SameCityCommodityGrowthRecordScreen: View {
    let archive: SameCityCommodityGrowthRecordArchive

    var body: some View {
        let previewMediaItems = SameCityCommodityGrowthRecordPreviewPlan.mediaItems(from: archive.entries)
        let previewAssets = SameCityCommodityGrowthRecordPreviewAssets.make(
            galleryID: imagePreviewGalleryID,
            mediaItems: previewMediaItems
        )

        MHBScreenScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                SameCityCommodityGrowthRecordSummary(
                    title: archive.title,
                    summaryText: archive.summaryText
                )

                SameCityCommodityGrowthRecordTimeline(
                    entries: archive.entries,
                    galleryID: imagePreviewGalleryID,
                    previewMediaItems: previewMediaItems,
                    previewAssets: previewAssets
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .mhbImagePreviewHost()
        .navigationTitle(archive.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .accessibilityIdentifier("sameCity.commodityGrowthRecord.screen")
    }

    private var imagePreviewGalleryID: String {
        "same-city-growth-record-\(archive.title)"
    }
}

// SameCityCommodityGrowthRecordSummary 成长档案摘要
// 核心职责：
// - 展示成长记录标题
// - 展示记录人和回忆数量摘要
private struct SameCityCommodityGrowthRecordSummary: View {
    let title: String
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
                .fixedSize(horizontal: false, vertical: true)

            Text(summaryText)
                .font(MHBTheme.Typography.callout.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// SameCityCommodityGrowthRecordTimeline 成长档案时间轴
// 核心职责：
// - 按时间顺序展示成长记录条目
// - 使用纵向轴线连接记录节点
private struct SameCityCommodityGrowthRecordTimeline: View {
    let entries: [SameCityCommodityGrowthRecordEntry]
    let galleryID: String
    let previewMediaItems: [SameCityCommodityGrowthRecordMediaItem]
    let previewAssets: [MHBImagePreviewAsset]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(width: 2)
                .padding(.leading, SameCityCommodityGrowthRecordLayout.timelineLineLeading)
                .padding(.top, MHBTheme.Spacing.s2)
                .padding(.bottom, MHBTheme.Spacing.s8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
                ForEach(entries) { entry in
                    SameCityCommodityGrowthRecordTimelineItem(
                        entry: entry,
                        galleryID: galleryID,
                        previewMediaItems: previewMediaItems,
                        previewAssets: previewAssets
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// SameCityCommodityGrowthRecordTimelineItem 成长档案时间轴条目
// 核心职责：
// - 展示单条成长记录的时间、标签、正文和媒体
// - 保持节点、正文和图片网格的横向对齐
private struct SameCityCommodityGrowthRecordTimelineItem: View {
    let entry: SameCityCommodityGrowthRecordEntry
    let galleryID: String
    let previewMediaItems: [SameCityCommodityGrowthRecordMediaItem]
    let previewAssets: [MHBImagePreviewAsset]

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            SameCityCommodityGrowthRecordNode(style: entry.nodeStyle)
                .padding(.top, MHBTheme.Spacing.s1)
                .frame(width: SameCityCommodityGrowthRecordLayout.nodeColumnWidth)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                SameCityCommodityGrowthRecordEntryHeader(
                    dateText: entry.dateText,
                    ageText: entry.ageText
                )

                if let dataTag = entry.dataTag {
                    SameCityCommodityGrowthRecordDataTagView(tag: dataTag)
                }

                Text(entry.content)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineSpacing(MHBTheme.Spacing.s1)
                    .fixedSize(horizontal: false, vertical: true)

                if entry.mediaItems.isEmpty == false {
                    SameCityCommodityGrowthRecordMediaGrid(
                        items: entry.mediaItems,
                        galleryID: galleryID,
                        previewMediaItems: previewMediaItems,
                        previewAssets: previewAssets
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// SameCityCommodityGrowthRecordNode 成长档案时间轴节点
// 核心职责：
// - 以圆点标记单条记录位置
// - 通过颜色区分普通、医疗和里程碑记录
private struct SameCityCommodityGrowthRecordNode: View {
    let style: SameCityCommodityGrowthRecordNodeStyle

    var body: some View {
        Circle()
            .fill(MHBTheme.ColorToken.background.color)
            .frame(
                width: SameCityCommodityGrowthRecordLayout.nodeSize,
                height: SameCityCommodityGrowthRecordLayout.nodeSize
            )
            .overlay {
                Circle()
                    .strokeBorder(style.borderColor, lineWidth: 3)
            }
    }
}

// SameCityCommodityGrowthRecordEntryHeader 成长档案记录头部
// 核心职责：
// - 展示记录日期
// - 使用年龄胶囊补充宠物成长阶段
private struct SameCityCommodityGrowthRecordEntryHeader: View {
    let dateText: String
    let ageText: String

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
            Text(dateText)
                .font(MHBTheme.Typography.headline.weight(.heavy))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text(ageText)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
                .padding(.horizontal, MHBTheme.Spacing.s2)
                .padding(.vertical, MHBTheme.Spacing.s1)
                .background(
                    MHBTheme.ColorToken.separatorSoft.color,
                    in: .rect(cornerRadius: MHBTheme.Radius.small)
                )
        }
    }
}

// SameCityCommodityGrowthRecordDataTagView 成长档案数据标签
// 核心职责：
// - 展示疫苗或体重等关键结构化记录
// - 使用图标和强调色提高扫描效率
private struct SameCityCommodityGrowthRecordDataTagView: View {
    let tag: SameCityCommodityGrowthRecordDataTag

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            Image(systemName: tag.systemImage)
                .font(.system(size: 11, weight: .bold))

            Text(tag.text)
                .font(MHBTheme.Typography.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(tag.style.foregroundColor)
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s1)
        .background(tag.style.backgroundColor, in: .rect(cornerRadius: MHBTheme.Radius.small))
    }
}

// SameCityCommodityGrowthRecordMediaGrid 成长档案媒体网格
// 核心职责：
// - 根据媒体数量展示一列、两列或三列图片
// - 保持图片圆角、内描边和固定画幅
private struct SameCityCommodityGrowthRecordMediaGrid: View {
    let items: [SameCityCommodityGrowthRecordMediaItem]
    let galleryID: String
    let previewMediaItems: [SameCityCommodityGrowthRecordMediaItem]
    let previewAssets: [MHBImagePreviewAsset]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ForEach(items) { item in
                SameCityCommodityGrowthRecordMediaCell(
                    item: item,
                    galleryID: galleryID,
                    previewAssets: previewAssets,
                    previewIndex: SameCityCommodityGrowthRecordPreviewPlan.previewIndex(
                        for: item.id,
                        in: previewMediaItems
                    )
                )
            }
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: MHBTheme.Spacing.s2),
            count: min(max(items.count, 1), 3)
        )
    }
}

// SameCityCommodityGrowthRecordMediaCell 成长档案媒体单元
// 核心职责：
// - 展示本地成长记录图片
// - 使用稳定画幅避免图片加载造成布局跳动
private struct SameCityCommodityGrowthRecordMediaCell: View {
    let item: SameCityCommodityGrowthRecordMediaItem
    let galleryID: String
    let previewAssets: [MHBImagePreviewAsset]
    let previewIndex: Int

    var body: some View {
        MHBPreviewableImage(
            galleryID: galleryID,
            items: previewAssets,
            index: previewIndex,
            cornerRadius: MHBTheme.Radius.large,
            contentMode: .fill
        ) {
            MHBTheme.ColorToken.separatorSoft.color
        }
            .aspectRatio(item.aspect.ratio, contentMode: .fill)
            .clipShape(.rect(cornerRadius: MHBTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
            .clipped()
    }
}

// SameCityCommodityGrowthRecordLayout 成长档案布局参数
// 核心职责：
// - 收敛顶部栏、时间轴和节点尺寸
// - 保持页面关键布局数值稳定
private enum SameCityCommodityGrowthRecordLayout {
    static let nodeSize: CGFloat = 12
    static let nodeColumnWidth: CGFloat = 24
    static let timelineLineLeading: CGFloat = 11
}

// SameCityCommodityGrowthRecordPreviewAssets 成长档案预览资源构造器
// 核心职责：
// - 将成长记录媒体转换为图片预览基础设施资源
// - 保持图集 ID 和资源顺序与页面时间轴一致
private enum SameCityCommodityGrowthRecordPreviewAssets {
    static func make(
        galleryID: String,
        mediaItems: [SameCityCommodityGrowthRecordMediaItem]
    ) -> [MHBImagePreviewAsset] {
        MHBImagePreviewAsset.localGallery(
            galleryID: galleryID,
            items: mediaItems.map { mediaItem in
                MHBImagePreviewAsset.LocalGalleryItem(
                    imageName: mediaItem.assetName,
                    pixelSize: mediaItem.pixelSize
                )
            }
        )
    }
}

// SameCityCommodityGrowthRecordMissingScreen 成长档案缺失占位页
// 核心职责：
// - 展示成长记录路由缺失时的轻量占位
// - 保持系统导航返回能力可用
struct SameCityCommodityGrowthRecordMissingScreen: View {
    var body: some View {
        Text("成长记录暂时不可查看")
            .font(MHBTheme.Typography.body)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("成长档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private extension SameCityCommodityGrowthRecordNodeStyle {
    var borderColor: Color {
        switch self {
        case .regular:
            MHBTheme.ColorToken.labelTertiary.color
        case .medical:
            MHBTheme.ColorToken.success.color
        case .milestone:
            MHBTheme.ColorToken.warning.color
        }
    }
}

private extension SameCityCommodityGrowthRecordDataTagStyle {
    var foregroundColor: Color {
        switch self {
        case .medical:
            MHBTheme.ColorToken.success.color
        case .weight:
            MHBTheme.ColorToken.warning.color
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

private extension SameCityCommodityGrowthRecordMediaAspect {
    var ratio: CGFloat {
        switch self {
        case .square:
            1
        case .portrait:
            3.0 / 4.0
        }
    }
}
