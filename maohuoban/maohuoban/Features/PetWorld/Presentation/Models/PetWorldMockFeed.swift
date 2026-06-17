import Foundation

// PetWorldMockFeed 宠物世界快速 UI mock 数据
// 核心职责：
// - 在后端 Feed 接口接入前提供可视化内容
// - 覆盖关系、优质、成长和经验等混合推荐形态
enum PetWorldMockFeed {
    static let snapshot = PetWorldFeedSnapshot(
        selectedPetName: "糯米",
        subtitle: "基于品种、年龄阶段和优质内容混合推荐",
        tabs: PetWorldFeedTab.allCases,
        hintChips: ["布偶猫", "幼猫", "优质经验", "新鲜内容"],
        items: [
            PetWorldFeedItem(
                id: "feed-naigai-food",
                pet: PetWorldPetSummary(
                    name: "奶盖",
                    breed: "布偶猫",
                    ageStage: "8个月",
                    systemImage: "cat.fill"
                ),
                media: PetWorldMediaPresentation(
                    tone: .primary,
                    systemImage: "fork.knife",
                    title: "换粮记录",
                    subtitle: "幼猫肠胃适应第 4 天"
                ),
                text: "最近开始慢慢换粮，少量混合旧粮后状态稳定了很多，便便也比前两天更成型。",
                topics: ["幼猫成长", "换粮"],
                badge: PetWorldRecommendationBadge(
                    title: "同龄",
                    explanation: "因为糯米也处于幼猫阶段，系统推荐了相近成长记录。",
                    style: .relation
                ),
                reactions: PetWorldReactionSummary(
                    likeCount: 128,
                    commentCount: 24,
                    saveCount: 36
                ),
                authorName: "小林"
            ),
            PetWorldFeedItem(
                id: "feed-ahuang-care",
                pet: PetWorldPetSummary(
                    name: "阿黄",
                    breed: "柯基",
                    ageStage: "2岁",
                    systemImage: "dog.fill"
                ),
                media: PetWorldMediaPresentation(
                    tone: .teal,
                    systemImage: "shower.fill",
                    title: "洗护经验",
                    subtitle: "短腿犬雨天回家清洁"
                ),
                text: "雨天出门后先擦脚垫再吹干腹部，皮肤状态会稳定很多，回家流程固定后它也不抗拒了。",
                topics: ["日常护理", "雨天出行"],
                badge: PetWorldRecommendationBadge(
                    title: "优质",
                    explanation: "这条护理经验近期收藏率较高，适合作为通用养护参考。",
                    style: .quality
                ),
                reactions: PetWorldReactionSummary(
                    likeCount: 342,
                    commentCount: 41,
                    saveCount: 118
                ),
                authorName: "阿南"
            ),
            PetWorldFeedItem(
                id: "feed-doudou-home",
                pet: PetWorldPetSummary(
                    name: "豆豆",
                    breed: "英短",
                    ageStage: "到家第7天",
                    systemImage: "cat.fill"
                ),
                media: PetWorldMediaPresentation(
                    tone: .purple,
                    systemImage: "house.fill",
                    title: "到家适应",
                    subtitle: "从躲沙发到主动巡视"
                ),
                text: "第七天终于开始主动出来探索客厅，晚上也会靠近人睡觉，胆小猫真的需要多给一点时间。",
                topics: ["到家记录", "胆小猫"],
                badge: PetWorldRecommendationBadge(
                    title: "成长",
                    explanation: "这是一条相近阶段的成长记录。",
                    style: .growth
                ),
                reactions: PetWorldReactionSummary(
                    likeCount: 96,
                    commentCount: 18,
                    saveCount: 27
                ),
                authorName: "清清"
            )
        ]
    )
}
