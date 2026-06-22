import ActivityKit
import SwiftUI
import WidgetKit

// PetWalkLiveActivityWidget 遛弯实时事件 Widget
// 核心职责：
// - 渲染锁屏实时事件和灵动岛展开态
// - 渲染灵动岛紧凑态的上下轮播信息
struct PetWalkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetWalkActivityAttributes.self) { context in
            PetWalkLockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PetWalkIslandCenterContentView(
                        petName: context.state.petName,
                        petAvatarURLString: context.state.petAvatarURLString,
                        statusText: context.state.statusText,
                        status: context.state.status,
                        distanceValueText: context.state.distanceValueText,
                        distanceUnitText: context.state.distanceUnitText,
                        caloriesText: context.state.caloriesText,
                        elapsedText: context.state.elapsedText
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    PetWalkIslandActionRowView(status: context.state.status)
                }
            } compactLeading: {
                PetWalkIslandCompactPetView(
                    avatarURLString: context.state.compactPetAvatarURLString,
                    status: context.state.status
                )
            } compactTrailing: {
                PetWalkIslandCompactRotatingTextView(state: context.state)
            } minimal: {
                PetWalkIslandMinimalView(status: context.state.status)
            }
            .keylineTint(context.state.status.accentColor)
        }
    }
}

// PetWalkLockScreenLiveActivityView 锁屏实时事件视图
// 核心职责：
// - 展示遛弯实时事件的完整摘要
// - 保持与灵动岛展开态一致的黑底和绿色运动状态
private struct PetWalkLockScreenLiveActivityView: View {
    let state: PetWalkActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                PetWalkPetAvatarView(
                    avatarURLString: state.petAvatarURLString,
                    size: 44,
                    status: state.status
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.petName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    PetWalkStatusBadgeView(statusText: state.statusText, status: state.status)
                }

                Spacer(minLength: 12)

                Text(state.elapsedText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.status.accentColor)
            }

            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(state.distanceValueText)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text(state.distanceUnitText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.caloriesText)
                        .font(.callout.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("已消耗")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(20)
    }
}

// PetWalkIslandCenterContentView 灵动岛展开态中心内容区
// 核心职责：
// - 承载宠物头像、姓名、状态标签、时长与核心运动指标
// - 按照设计稿横向并排的三行式布局，利用 .center 区域避开系统物理遮挡
private struct PetWalkIslandCenterContentView: View {
    let petName: String
    let petAvatarURLString: String?
    let statusText: String
    let status: PetWalkLiveActivityStatus
    let distanceValueText: String
    let distanceUnitText: String
    let caloriesText: String
    let elapsedText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一行：Header (头像 + 名字与状态 + 时长)
            HStack(alignment: .center, spacing: 10) {
                PetWalkPetAvatarView(
                    avatarURLString: petAvatarURLString,
                    size: 44,
                    status: status
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(petName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    PetWalkStatusBadgeView(statusText: statusText, status: status)
                }

                Spacer()

                Text(elapsedText)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(status.accentColor)
            }

            // 第二行：Metric (距离 + 消耗)
            HStack(alignment: .bottom) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(distanceValueText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text(distanceUnitText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(caloriesText)
                        .font(.system(size: 16, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("已消耗")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// PetWalkIslandActionRowView 灵动岛展开态操作区
// 核心职责：
// - 提供展开态底部操作文案的视觉承载
// - 保持第一版前端功能不引入 AppIntent 写操作
private struct PetWalkIslandActionRowView: View {
    let status: PetWalkLiveActivityStatus

    var body: some View {
        HStack(spacing: 12) {
            PetWalkIslandActionLabel(
                title: "收起面板",
                systemImage: "arrow.down.right.and.arrow.up.left",
                foregroundColor: status == .paused ? .yellow : status.accentColor,
                backgroundColor: Color.white.opacity(0.14)
            )

            PetWalkIslandActionLabel(
                title: "长按结束",
                systemImage: "stop.fill",
                foregroundColor: .white,
                backgroundColor: Color.red
            )
        }
    }
}

// PetWalkIslandCompactPetView 灵动岛紧凑态宠物视图
// 核心职责：
// - 展示紧凑态左侧宠物头像占位
// - 展示实时状态点
private struct PetWalkIslandCompactPetView: View {
    let avatarURLString: String?
    let status: PetWalkLiveActivityStatus

    var body: some View {
        HStack(spacing: 5) {
            PetWalkPetAvatarView(avatarURLString: avatarURLString, size: 24, status: status)

            Circle()
                .fill(status.accentColor)
                .frame(width: 6, height: 6)
                .shadow(color: status.accentColor, radius: 4)
        }
    }
}

// PetWalkIslandCompactRotatingTextView 灵动岛紧凑态轮播文字
// 核心职责：
// - 按时间、状态、距离顺序切换收起态内容
// - 使用向上滚动转场表达实时状态切换
private struct PetWalkIslandCompactRotatingTextView: View {
    let state: PetWalkActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: state.updatedAt, by: 2.2)) { timeline in
            let item = state.compactRotationItem(at: timeline.date)

            Text(item.text)
                .id(item.id)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(state.status.accentColor)
                .contentTransition(.numericText(countsDown: false))
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
                .animation(.smooth(duration: 0.28), value: item.id)
        }
        .frame(width: 68, height: 20, alignment: .trailing)
        .clipped()
    }
}

// PetWalkIslandMinimalView 灵动岛最小态视图
// 核心职责：
// - 在最小灵动岛状态展示遛弯标识
// - 用状态色表达进行中或暂停
private struct PetWalkIslandMinimalView: View {
    let status: PetWalkLiveActivityStatus

    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(status.accentColor)
    }
}

// PetWalkPetAvatarView 遛弯宠物头像视图
// 核心职责：
// - 优先展示实时事件状态中的宠物头像 URL
// - 在头像不可用时提供宠物视觉锚点
// - 保持锁屏、展开态和紧凑态头像尺寸一致性
private struct PetWalkPetAvatarView: View {
    let avatarURLString: String?
    let size: CGFloat
    let status: PetWalkLiveActivityStatus

    var body: some View {
        Group {
            if let avatarURLString,
               let url = URL(string: avatarURLString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        PetWalkPetAvatarPlaceholderView(size: size, status: status)
                    @unknown default:
                        PetWalkPetAvatarPlaceholderView(size: size, status: status)
                    }
                }
            } else {
                PetWalkPetAvatarPlaceholderView(size: size, status: status)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

// PetWalkPetAvatarPlaceholderView 遛弯宠物头像占位视图
// 核心职责：
// - 在头像 URL 不可用或加载失败时展示宠物标识
// - 保持实时事件各状态头像视觉一致
private struct PetWalkPetAvatarPlaceholderView: View {
    let size: CGFloat
    let status: PetWalkLiveActivityStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.16))

            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(status.accentColor)
        }
    }
}

// PetWalkStatusBadgeView 遛弯状态标签视图
// 核心职责：
// - 展示状态图标和状态文案
// - 统一进行中、暂停和结束三种状态的颜色
private struct PetWalkStatusBadgeView: View {
    let statusText: String
    let status: PetWalkLiveActivityStatus

    var body: some View {
        Label(statusText, systemImage: "location.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.accentColor)
    }
}

// PetWalkIslandActionLabel 灵动岛操作标签
// 核心职责：
// - 复用展开态底部胶囊式操作视觉
// - 避免 Widget 第一版引入命令式副作用
private struct PetWalkIslandActionLabel: View {
    let title: String
    let systemImage: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.bold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(backgroundColor, in: Capsule())
    }
}

// PetWalkLiveActivityWidgetSupport 遛弯 Widget 展示支持
// 核心职责：
// - 提供紧凑态轮播选择逻辑
// - 提供实时事件状态色
private extension PetWalkActivityAttributes.ContentState {
    func compactRotationItem(at date: Date) -> PetWalkLiveActivityCompactItem {
        let items = compactRotationItems
        guard items.isEmpty == false else {
            return PetWalkLiveActivityCompactItem(kind: .status, text: statusText)
        }

        let step = max(0, Int(date.timeIntervalSince(updatedAt) / 2.2))
        return items[step % items.count]
    }
}

private extension PetWalkLiveActivityStatus {
    var accentColor: Color {
        switch self {
        case .tracking:
            Color(red: 0.20, green: 0.83, blue: 0.60)
        case .paused:
            Color(red: 0.96, green: 0.62, blue: 0.04)
        case .finished:
            Color.white.opacity(0.74)
        }
    }
}
