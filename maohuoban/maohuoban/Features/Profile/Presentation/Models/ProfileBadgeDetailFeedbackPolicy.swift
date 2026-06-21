import CoreGraphics

// ProfileBadgeDetailFeedbackPolicy 勋章详情反馈策略
// 核心职责：
// - 判断勋章详情弹层出现时是否需要触发奖励触感
// - 提供已获得勋章弹层反馈的强度配置
// - 保持未获得勋章无奖励反馈的产品边界
struct ProfileBadgeDetailFeedbackPolicy {
    static let presentationFeedbackIntensity: CGFloat = 1.0

    static func shouldTriggerPresentationFeedback(for badge: ProfileBadge) -> Bool {
        badge.isEarned
    }
}
