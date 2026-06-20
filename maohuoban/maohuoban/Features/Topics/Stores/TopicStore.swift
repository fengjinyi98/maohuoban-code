import Foundation
import Observation

// TopicStore 话题快速 UI 状态源
// 核心职责：
// - 管理话题 mock 数据、关注关系和详情页帖子预览
// - 响应用户手动输入创建话题、关注切换和发布草稿选择
@MainActor
@Observable
final class TopicStore {
    private(set) var topics: [TopicSummary]
    private(set) var followedTopicIDs: Set<String>
    private(set) var followedTopics: [TopicSummary]
    private var postsByTopicID: [String: [TopicPostPreview]]

    init() {
        let seedTopics = Self.seedTopics
        let seedFollowedTopicIDs = Set(seedTopics.prefix(8).map(\.id))

        topics = seedTopics
        followedTopicIDs = seedFollowedTopicIDs
        followedTopics = seedTopics.filter { seedFollowedTopicIDs.contains($0.id) }
        postsByTopicID = Self.seedPostsByTopicID
    }

    // topic 读取指定话题
    // 核心职责：
    // - 为路由目标提供当前话题快照
    // - 在缺失时交由页面渲染空态
    func topic(id: String) -> TopicSummary? {
        topics.first { $0.id == id }
    }

    // topicID 解析展示名称对应的话题 ID
    // 核心职责：
    // - 让详情页字符串话题 chip 可以进入稳定话题路由
    // - 保持解析过程为纯函数
    func topicID(forName name: String) -> String {
        TopicIdentifier.id(for: name)
    }

    // isFollowed 判断话题关注状态
    // 核心职责：
    // - 为话题列表和详情页提供关注按钮状态
    func isFollowed(topicID: String) -> Bool {
        followedTopicIDs.contains(topicID)
    }

    // toggleFollow 切换话题关注状态
    // 核心职责：
    // - 响应用户关注或取消关注点击
    // - 同步刷新我的关注话题列表快照
    func toggleFollow(topicID: String) {
        if followedTopicIDs.contains(topicID) {
            followedTopicIDs.remove(topicID)
        } else {
            followedTopicIDs.insert(topicID)
        }
        recomputeFollowedTopics()
    }

    // createOrFollowTopic 创建或关注话题
    // 核心职责：
    // - 根据用户手动输入创建本地话题
    // - 已存在话题时直接补充关注关系并返回现有话题
    @discardableResult
    func createOrFollowTopic(named rawName: String) -> TopicSummary? {
        let name = TopicIdentifier.normalizedName(rawName)
        guard !name.isEmpty else {
            return nil
        }

        let id = TopicIdentifier.id(for: name)
        if let existingTopic = topic(id: id) {
            followedTopicIDs.insert(existingTopic.id)
            recomputeFollowedTopics()
            return existingTopic
        }

        let topic = TopicSummary(
            id: id,
            name: name,
            description: "由用户创建的新话题，后续会沉淀为 UGC 分类、推荐召回和 RAG 过滤信号。",
            thumbnailAssetName: "HomeGalleryAlbum3",
            followerCount: 1,
            postCount: 0,
            todayPostCount: 0,
            isUserCreated: true
        )

        topics.insert(topic, at: 0)
        followedTopicIDs.insert(topic.id)
        postsByTopicID[topic.id] = []
        recomputeFollowedTopics()
        return topic
    }

    // topicPosts 读取话题详情帖子预览
    // 核心职责：
    // - 为话题详情页提供当前话题下的 UGC 列表
    // - 新建话题在尚无内容时返回空列表
    func topicPosts(topicID: String) -> [TopicPostPreview] {
        postsByTopicID[topicID] ?? []
    }

    // selectableTopics 读取发布草稿可选话题
    // 核心职责：
    // - 为发布手动话题输入页提供稳定候选列表
    // - 排除已选择的话题，避免重复添加
    func selectableTopics(excluding selectedTopicIDs: Set<String>) -> [TopicSummary] {
        topics.filter { !selectedTopicIDs.contains($0.id) }
    }

    private func recomputeFollowedTopics() {
        followedTopics = topics.filter { followedTopicIDs.contains($0.id) }
    }
}

private extension TopicStore {
    static let seedTopics: [TopicSummary] = [
        makeTopic("夏日剃毛翻车大赏", "夏天造型、剃毛翻车和护理复盘集中讨论。", "HomePetAlbum1", 18420, 326, 32),
        makeTopic("新手养宠必看", "疫苗、驱虫、喂养和初次到家适应经验。", "HomePetAlbum2", 53210, 1280, 12),
        makeTopic("沉浸式洗狗狗", "洗护流程、吹毛技巧和洗澡前后对比。", "HomeGalleryAlbum2", 9630, 214, 0),
        makeTopic("无限回购的宠物零食", "真实复购零食、适口性和成分讨论。", "HomePetFoodBowl", 14280, 498, 0),
        makeTopic("金毛寻回犬", "金毛成长、训练、掉毛和性格交流。", "HomePetAlbum3", 23000, 540, 8),
        makeTopic("猫咪日常", "猫咪睡姿、饮食、玩具和家庭生活记录。", "HomePetAlbum4", 58000, 920, 16),
        makeTopic("新手养宠避坑", "新手常见误区和真实踩坑复盘。", "HomeGalleryAlbum1", 894, 128, 5),
        makeTopic("宠物摄影", "拍照构图、光线和宠物出片技巧。", "HomeGalleryAlbum3", 1487, 76, 3),
        makeTopic("柴犬俱乐部", "柴犬表情包、训练和同城交流。", "HomeGalleryAlbum2", 4392, 142, 2),
        makeTopic("海边散步", "户外牵引、海边出行和清洁护理。", "HomePetHeroMock", 3290, 92, 4),
        makeTopic("布偶日常", "布偶猫性格、护理和家庭相处记录。", "HomePetAlbum2", 8460, 238, 7),
        makeTopic("宠物伙伴", "多宠家庭、朋友结伴和社交记录。", "HomePartnerAvatar", 6120, 180, 6),
        makeTopic("猫咪晒太阳", "阳台晒太阳、午睡和猫咪舒适角落。", "HomePetAlbum1", 5210, 166, 2),
        makeTopic("午睡日记", "宠物睡眠、窝垫和作息观察。", "HomePetAlbum4", 2180, 71, 1),
        makeTopic("公园训练", "户外召回、牵引和基础训练经验。", "HomeGalleryAlbum2", 3900, 144, 3),
        makeTopic("召回练习", "召回训练进度、奖励和环境干扰复盘。", "HomeGalleryAlbum3", 1760, 68, 1),
        makeTopic("狗狗成长", "幼犬成长、训练和健康记录。", "HomePetAlbum3", 10420, 361, 9),
        makeTopic("宠物日常", "普通但值得记录的陪伴瞬间。", "HomePetAlbum1", 74200, 1890, 24)
    ]

    static let seedPostsByTopicID: [String: [TopicPostPreview]] = {
        Dictionary(uniqueKeysWithValues: seedTopics.map { topic in
            (topic.id, makePosts(for: topic))
        })
    }()

    static func makeTopic(
        _ name: String,
        _ description: String,
        _ thumbnailAssetName: String,
        _ followerCount: Int,
        _ postCount: Int,
        _ todayPostCount: Int
    ) -> TopicSummary {
        TopicSummary(
            id: TopicIdentifier.id(for: name),
            name: name,
            description: description,
            thumbnailAssetName: thumbnailAssetName,
            followerCount: followerCount,
            postCount: postCount,
            todayPostCount: todayPostCount,
            isUserCreated: false
        )
    }

    static func makePosts(for topic: TopicSummary) -> [TopicPostPreview] {
        [
            TopicPostPreview(
                id: "\(topic.id)-post-1",
                authorName: "阿白和狗子",
                avatarAssetName: "HomeUserAvatarMock",
                publishedText: topic.todayPostCount > 0 ? "10 分钟前发布" : "昨天发布",
                mediaAssetName: topic.thumbnailAssetName,
                caption: "加入 \(topic.displayName) 后，终于把这次记录整理出来了，给正在做功课的伙伴一个真实参考。",
                likeCountText: "1.2k",
                commentCountText: "128"
            ),
            TopicPostPreview(
                id: "\(topic.id)-post-2",
                authorName: "阿May",
                avatarAssetName: "HomePartnerAvatar",
                publishedText: topic.todayPostCount > 0 ? "1 小时前发布" : "3 天前发布",
                mediaAssetName: "HomeGalleryAlbum1",
                caption: "这个话题下面的信息密度很高，先把我家这次的过程和结果补一条。",
                likeCountText: "892",
                commentCountText: "45"
            )
        ]
    }
}
