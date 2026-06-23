import Foundation

// ProfileReplyItem 我的回复列表项
// 核心职责：
// - 承载收到和发出回复的统一展示数据
// - 为回复内容、引用上下文和操作区提供稳定输入
struct ProfileReplyItem: Identifiable, Equatable {
    enum ContextKind: Equatable {
        case post(symbolName: String)
        case comment
    }

    let id: String
    let scope: ProfileReplyScope
    let actorName: String
    let actorBadgeText: String?
    let actorSymbolName: String
    let timeText: String
    let replyText: String
    let contextTitle: String
    let contextText: String
    let contextKind: ContextKind
    let primaryActionTitle: String
    let primaryActionSymbolName: String
    let secondaryActionTitle: String
    let secondaryActionSymbolName: String

    var searchableText: String {
        [
            actorName,
            actorBadgeText,
            replyText,
            contextTitle,
            contextText
        ]
        .compactMap(\.self)
        .joined(separator: " ")
    }

    var avatarSubject: MHBAvatarSubject {
        .user(
            MHBAvatarUser(
                id: id,
                displayName: actorName,
                source: .systemSymbol(actorSymbolName),
                sex: .unknown,
                sexVisibility: .hidden
            )
        )
    }
}

extension ProfileReplyItem {
    static func mockReply(
        id: String = UUID().uuidString,
        scope: ProfileReplyScope,
        actorName: String,
        actorBadgeText: String? = nil,
        actorSymbolName: String = "person.fill",
        timeText: String,
        replyText: String,
        contextTitle: String,
        contextText: String,
        contextKind: ContextKind,
        primaryActionTitle: String,
        primaryActionSymbolName: String,
        secondaryActionTitle: String,
        secondaryActionSymbolName: String
    ) -> ProfileReplyItem {
        ProfileReplyItem(
            id: id,
            scope: scope,
            actorName: actorName,
            actorBadgeText: actorBadgeText,
            actorSymbolName: actorSymbolName,
            timeText: timeText,
            replyText: replyText,
            contextTitle: contextTitle,
            contextText: contextText,
            contextKind: contextKind,
            primaryActionTitle: primaryActionTitle,
            primaryActionSymbolName: primaryActionSymbolName,
            secondaryActionTitle: secondaryActionTitle,
            secondaryActionSymbolName: secondaryActionSymbolName
        )
    }
}

extension Array where Element == ProfileReplyItem {
    static let profileReplyMockItems: [ProfileReplyItem] = [
        .mockReply(
            id: "reply-received-corgi",
            scope: .received,
            actorName: "李大锤爱柯基",
            actorSymbolName: "pawprint.fill",
            timeText: "10 分钟前",
            replyText: "天呐这也太可爱了吧！同在上海，求一个购猫的猫舍推荐！想接一只同款的弟弟。",
            contextTitle: "我的动态",
            contextText: "接糯米回家的第一天，简直是个粘人精～",
            contextKind: .post(symbolName: "photo.fill"),
            primaryActionTitle: "回复",
            primaryActionSymbolName: "bubble.left",
            secondaryActionTitle: "赞",
            secondaryActionSymbolName: "heart"
        ),
        .mockReply(
            id: "reply-received-stray-house",
            scope: .received,
            actorName: "阿May的流浪小屋",
            actorBadgeText: "志愿者",
            actorSymbolName: "heart.fill",
            timeText: "2 小时前",
            replyText: "没问题的，如果您那边已经封窗了，随时可以加微信详聊哦，感谢支持领养！",
            contextTitle: "我的评论",
            contextText: "请问这只三花妹妹还在吗？我家符合领养条件。",
            contextKind: .comment,
            primaryActionTitle: "回复",
            primaryActionSymbolName: "bubble.left",
            secondaryActionTitle: "赞",
            secondaryActionSymbolName: "heart"
        ),
        .mockReply(
            id: "reply-sent-cattery",
            scope: .sent,
            actorName: "星梦名猫苑",
            actorBadgeText: "认证猫舍",
            actorSymbolName: "sparkles",
            timeText: "昨天 14:30",
            replyText: "如果我和大厅里那个人一起买，专车大概多久能发车？坐标上海徐汇。",
            contextTitle: "@星梦名猫苑 的动态",
            contextText: "极品双血统金渐层弟弟，包子脸大眼睛，开放凑单中。",
            contextKind: .post(symbolName: "shippingbox.fill"),
            primaryActionTitle: "删除记录",
            primaryActionSymbolName: "trash",
            secondaryActionTitle: "查看原文",
            secondaryActionSymbolName: "arrow.up.right.square"
        ),
        .mockReply(
            id: "reply-sent-sarah",
            scope: .sent,
            actorName: "Sarah_Wang",
            actorSymbolName: "person.fill",
            timeText: "3 天前",
            replyText: "哈哈哈哈你家的边牧太聪明了吧，简直成精了！",
            contextTitle: "@Sarah_Wang 的评论",
            contextText: "我家狗子昨天甚至学会了自己开冰箱找肉吃...",
            contextKind: .comment,
            primaryActionTitle: "删除记录",
            primaryActionSymbolName: "trash",
            secondaryActionTitle: "查看原文",
            secondaryActionSymbolName: "arrow.up.right.square"
        )
    ]
}
