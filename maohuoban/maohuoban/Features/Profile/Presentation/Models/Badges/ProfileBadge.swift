import Foundation

// ProfileBadge 我的页勋章数据模型
// 核心职责：
// - 表达用户在个人中心获得并展示的成就勋章
// - 承载勋章资源、获得状态、进度和后端接入备注
struct ProfileBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let condition: String
    let quote: String
    let rarity: ProfileBadgeRarity
    let socialProof: String
    let imageAssetName: String
    let alternateImageAssetName: String?
    let backendSelectionNote: String?
    let systemImage: String
    let isEarned: Bool
    let progressCurrent: Int
    let progressTarget: Int

    var progressText: String {
        guard !isEarned else {
            return "已点亮"
        }

        return "\(progressCurrent)/\(progressTarget)"
    }

    var progressFraction: Double {
        guard progressTarget > 0 else {
            return 0
        }

        return min(max(Double(progressCurrent) / Double(progressTarget), 0), 1)
    }

    static let mockBadges: [ProfileBadge] = [
        ProfileBadge(
            id: "genesis_partner",
            title: "创世伙伴",
            description: "冷启动纪念勋章",
            condition: "内测、种子用户或平台早期注册用户。",
            quote: "在毛伙伴诞生之初，就已陪伴毛孩",
            rarity: .legendary,
            socialProof: "限量 5,000 人",
            imageAssetName: "BadgeGenesisPartner",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "pawprint.fill",
            isEarned: true,
            progressCurrent: 1,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "first_partner",
            title: "第一只伙伴",
            description: "创建首只宠物档案",
            condition: "成功创建第一只宠物档案。",
            quote: "TA 是你第一个毛绒家人",
            rarity: .normal,
            socialProof: "45.2w 人获得",
            imageAssetName: "BadgeFirstPartnerCat",
            alternateImageAssetName: "BadgeFirstPartnerDog",
            // 后端接入注意：第一只伙伴是猫/狗互斥勋章，一个用户只能获得第一只宠物物种对应的其中一个版本。
            backendSelectionNote: "第一只伙伴为互斥勋章，后端接入后根据用户创建的第一只宠物物种发放猫版或狗版其中一个。",
            systemImage: "pawprint.fill",
            isEarned: true,
            progressCurrent: 1,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "profile_complete",
            title: "档案初成",
            description: "宠物档案完整度达到 80%",
            condition: "任意一只宠物档案完整度达到 80%。",
            quote: "认真记录，就是最好的爱",
            rarity: .normal,
            socialProof: "38.5w 人获得",
            imageAssetName: "BadgeProfileComplete",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "checklist.checked",
            isEarned: true,
            progressCurrent: 1,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "home_stylist",
            title: "首页装扮师",
            description: "设置宠物头像或首页背景",
            condition: "成功设置宠物头像或首页静态背景。",
            quote: "把家装修成毛孩最喜欢的样子",
            rarity: .normal,
            socialProof: "12.1w 人获得",
            imageAssetName: "BadgeHomeStylist",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "paintbrush.fill",
            isEarned: false,
            progressCurrent: 0,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "seven_day_promise",
            title: "七日有约",
            description: "连续记录 7 天",
            condition: "连续 7 天完成任意宠物记录。",
            quote: "坚持就是最温暖的陪伴",
            rarity: .rare,
            socialProof: "8.9w 人获得",
            imageAssetName: "BadgeSevenDayPromise",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "calendar.badge.checkmark",
            isEarned: true,
            progressCurrent: 7,
            progressTarget: 7
        ),
        ProfileBadge(
            id: "monthly_caregiver",
            title: "月度照护官",
            description: "连续记录 30 天",
            condition: "连续记录 30 天。",
            quote: "一个月，我们一起长大",
            rarity: .rare,
            socialProof: "3.2w 人获得",
            imageAssetName: "BadgeMonthlyCaregiver",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "moon.fill",
            isEarned: false,
            progressCurrent: 12,
            progressTarget: 30
        ),
        ProfileBadge(
            id: "hundred_day_companion",
            title: "百日同行",
            description: "连续记录 100 天",
            condition: "连续记录 100 天。",
            quote: "100 天，我们已经是家人",
            rarity: .legendary,
            socialProof: "仅 1% 用户获得",
            imageAssetName: "BadgeHundredDayCompanion",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "map.fill",
            isEarned: false,
            progressCurrent: 12,
            progressTarget: 100
        ),
        ProfileBadge(
            id: "weight_observer",
            title: "体重观察员",
            description: "累计记录 10 次体重",
            condition: "累计记录 10 次体重。",
            quote: "关注体重，就是关注健康",
            rarity: .normal,
            socialProof: "12.5w 人获得",
            imageAssetName: "BadgeWeightObserver",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "scalemass.fill",
            isEarned: false,
            progressCurrent: 3,
            progressTarget: 10
        ),
        ProfileBadge(
            id: "vaccine_guardian",
            title: "疫苗守护者",
            description: "完成疫苗记录",
            condition: "完成至少 1 条有效疫苗记录。",
            quote: "我为毛孩的健康站岗",
            rarity: .rare,
            socialProof: "9.2w 人获得",
            imageAssetName: "BadgeVaccineGuardian",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "shield.fill",
            isEarned: true,
            progressCurrent: 1,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "deworming_reminder",
            title: "驱虫提醒官",
            description: "完成驱虫记录",
            condition: "完成至少 1 条有效驱虫记录。",
            quote: "定期守护，远离隐形威胁",
            rarity: .normal,
            socialProof: "15.2w 人获得",
            imageAssetName: "BadgeDewormingReminder",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "ladybug.fill",
            isEarned: false,
            progressCurrent: 0,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "home_anniversary",
            title: "回家纪念日",
            description: "记录宠物到家日期",
            condition: "记录宠物的到家或领养日期。",
            quote: "从今天起，你就是我的全世界",
            rarity: .rare,
            socialProof: "21.5w 人获得",
            imageAssetName: "BadgeHomeAnniversary",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "house.fill",
            isEarned: true,
            progressCurrent: 1,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "birthday_recorder",
            title: "生日记录官",
            description: "记录宠物生日",
            condition: "记录宠物的生日。",
            quote: "每年这一天，都要一起庆祝",
            rarity: .rare,
            socialProof: "18.9w 人获得",
            imageAssetName: "BadgeBirthdayRecorder",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "birthday.cake.fill",
            isEarned: false,
            progressCurrent: 0,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "hundred_memories",
            title: "百张回忆",
            description: "相册累计 100 张照片",
            condition: "相册累计上传 100 张照片。",
            quote: "每一张，都是珍贵的时光",
            rarity: .epic,
            socialProof: "4.5w 人获得",
            imageAssetName: "BadgeHundredMemories",
            alternateImageAssetName: nil,
            backendSelectionNote: "上传宠物照片只计入影像勋章和容量额度，不产生经验。",
            systemImage: "photo.on.rectangle.angled",
            isEarned: false,
            progressCurrent: 45,
            progressTarget: 100
        ),
        ProfileBadge(
            id: "community_star",
            title: "社区新星",
            description: "发布首条宠物动态",
            condition: "发布第一条宠物动态。",
            quote: "我在毛伙伴发出第一声",
            rarity: .normal,
            socialProof: "32.1w 人获得",
            imageAssetName: "BadgeCommunityStar",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "star.fill",
            isEarned: true,
            progressCurrent: 1,
            progressTarget: 1
        ),
        ProfileBadge(
            id: "experience_sharer",
            title: "经验分享者",
            description: "发布 3 条经验类内容",
            condition: "累计发布 3 条经验类内容。",
            quote: "把爱和知识传递给更多人",
            rarity: .normal,
            socialProof: "2.8w 人获得",
            imageAssetName: "BadgeExperienceSharer",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "square.and.arrow.up.fill",
            isEarned: false,
            progressCurrent: 1,
            progressTarget: 3
        ),
        ProfileBadge(
            id: "love_ambassador",
            title: "爱心使者",
            description: "参与救助、领养或公益活动",
            condition: "参与平台救助、领养或官方公益活动。",
            quote: "因为爱，世界变得更好",
            rarity: .legendary,
            socialProof: "仅 0.5% 用户获得",
            imageAssetName: "BadgeLoveAmbassador",
            alternateImageAssetName: nil,
            backendSelectionNote: nil,
            systemImage: "heart.fill",
            isEarned: false,
            progressCurrent: 0,
            progressTarget: 1
        )
    ]
}
