import Foundation

// FeedRecommendationReason Feed 推荐解释
// 核心职责：
// - 限定快速 UI 阶段卡片可展示的推荐关系类型
// - 承载后端或 mock 数据映射后的具体解释文案
struct FeedRecommendationReason: Equatable {
    let kind: Kind
    let text: String

    // Kind 推荐解释类型
    // 核心职责：
    // - 对齐 UGC 内容流推荐池类型
    // - 限制 UI 阶段只展示轻关系和优质内容
    enum Kind: Equatable {
        case lightRelationship
        case qualityContent
    }

    // lightRelationship 构造轻关系解释
    // 核心职责：
    // - 承接由宠物档案字段推导出的冷启动关系文案
    // - 保持 UI 只消费已成型展示文本
    static func lightRelationship(_ text: String) -> Self {
        Self(kind: .lightRelationship, text: text)
    }

    // qualityContent 构造优质内容解释
    // 核心职责：
    // - 承接由内容质量信号推导出的推荐解释文案
    // - 保持 UI 只消费已成型展示文本
    static func qualityContent(_ text: String) -> Self {
        Self(kind: .qualityContent, text: text)
    }
}
