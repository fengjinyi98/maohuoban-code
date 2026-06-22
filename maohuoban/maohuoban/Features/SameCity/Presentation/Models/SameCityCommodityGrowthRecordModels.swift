import Foundation

// SameCityCommodityGrowthRecordCard 商品详情成长记录卡片
// 核心职责：
// - 表达发布商品时导入的宠物成长记录摘要
// - 为商品详情页提供缩略图预览和剩余记录计数
struct SameCityCommodityGrowthRecordCard: Equatable {
    let title: String
    let recordCount: Int
    let thumbnailAssetNames: [String]
    let archive: SameCityCommodityGrowthRecordArchive

    var summaryText: String {
        "包含 \(recordCount) 条图文动态"
    }

    var remainingThumbnailCount: Int {
        max(recordCount - thumbnailAssetNames.count, 0)
    }
}

// SameCityCommodityGrowthRecordArchive 商品成长记录档案
// 核心职责：
// - 承载成长档案全屏页的头部摘要与时间轴数据
// - 隔离商品详情入口卡片和记录详情展示数据
struct SameCityCommodityGrowthRecordArchive: Equatable {
    let navigationTitle: String
    let title: String
    let recorderName: String
    let memoryCount: Int
    let entries: [SameCityCommodityGrowthRecordEntry]

    var summaryText: String {
        "由 \(recorderName) 记录 · 共 \(memoryCount) 条回忆"
    }
}

// SameCityCommodityGrowthRecordEntry 商品成长记录时间轴条目
// 核心职责：
// - 描述一条成长记录的时间、年龄、正文和媒体
// - 为时间轴节点和关键数据标签提供展示语义
struct SameCityCommodityGrowthRecordEntry: Identifiable, Equatable {
    let id: String
    let dateText: String
    let ageText: String
    let nodeStyle: SameCityCommodityGrowthRecordNodeStyle
    let dataTag: SameCityCommodityGrowthRecordDataTag?
    let content: String
    let mediaItems: [SameCityCommodityGrowthRecordMediaItem]
}

// SameCityCommodityGrowthRecordDataTag 成长记录关键数据标签
// 核心职责：
// - 表达疫苗、体重等结构化记录
// - 为标签图标和强调色提供稳定输入
struct SameCityCommodityGrowthRecordDataTag: Equatable {
    let systemImage: String
    let text: String
    let style: SameCityCommodityGrowthRecordDataTagStyle
}

// SameCityCommodityGrowthRecordMediaItem 成长记录媒体项
// 核心职责：
// - 描述成长记录中的本地图片资源
// - 为图片网格提供稳定身份和画幅比例
struct SameCityCommodityGrowthRecordMediaItem: Identifiable, Equatable {
    let id: String
    let assetName: String
    let aspect: SameCityCommodityGrowthRecordMediaAspect
}

// SameCityCommodityGrowthRecordNodeStyle 成长记录节点样式
// 核心职责：
// - 区分普通、医疗和里程碑节点
// - 为时间轴节点颜色提供业务语义
enum SameCityCommodityGrowthRecordNodeStyle: Equatable {
    case regular
    case medical
    case milestone
}

// SameCityCommodityGrowthRecordDataTagStyle 成长记录标签样式
// 核心职责：
// - 区分医疗和体重等关键数据标签
// - 为标签背景和前景色提供业务语义
enum SameCityCommodityGrowthRecordDataTagStyle: Equatable {
    case medical
    case weight
}

// SameCityCommodityGrowthRecordMediaAspect 成长记录媒体画幅
// 核心职责：
// - 描述图片在时间轴网格中的固定比例
// - 保持图片加载前后布局稳定
enum SameCityCommodityGrowthRecordMediaAspect: Equatable {
    case square
    case portrait
}

// SameCityCommodityDetailContentSeparatorPolicy 商品详情正文分割线策略
// 核心职责：
// - 根据成长记录卡片展示状态决定相邻 section 分割线
// - 保持商品详情正文结构判断集中可测
struct SameCityCommodityDetailContentSeparatorPolicy: Equatable {
    let showsDividerAfterTitle: Bool
    let showsDividerAfterGrowthRecordCard: Bool

    static func resolve(hasGrowthRecordCard: Bool) -> SameCityCommodityDetailContentSeparatorPolicy {
        SameCityCommodityDetailContentSeparatorPolicy(
            showsDividerAfterTitle: !hasGrowthRecordCard,
            showsDividerAfterGrowthRecordCard: false
        )
    }
}

// SameCityCommodityGrowthRecordPreviewPlan 成长记录图片预览计划
// 核心职责：
// - 将时间轴中的媒体按展示顺序展开为同一预览图集
// - 根据媒体 ID 解析点击图片在预览图集中的起始位置
enum SameCityCommodityGrowthRecordPreviewPlan {
    static func mediaItems(
        from entries: [SameCityCommodityGrowthRecordEntry]
    ) -> [SameCityCommodityGrowthRecordMediaItem] {
        entries.flatMap(\.mediaItems)
    }

    static func previewIndex(
        for mediaID: String,
        in mediaItems: [SameCityCommodityGrowthRecordMediaItem]
    ) -> Int {
        mediaItems.firstIndex { $0.id == mediaID } ?? 0
    }
}
