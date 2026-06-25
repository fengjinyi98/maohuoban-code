import Foundation
import SwiftUI
import MaohuobanDesignSystem

// HomeTimelineSection 最近时间线模块
// 核心职责：
// - 展示当前宠物今天记录的关键时间线事件
// - 呈现高对比度、呼吸感强的磨砂玻璃时间轴卡片
struct HomeTimelineSection: View {
    let events: [HomeDashboardSnapshot.TimelineEvent]

    private var displayedEvents: [HomeDashboardSnapshot.TimelineEvent] {
        Array(events.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HomeTimelineHeader()

            // 时间轴垂直列表
            VStack(spacing: 0) {
                ForEach(Array(displayedEvents.enumerated()), id: \.element.id) { index, event in
                    let isFirst = index == 0
                    let isLast = index == displayedEvents.count - 1

                    NavigationLink(value: HomeRoute.timelineEvent(eventID: event.id)) {
                        HomeTimelineRow(
                            event: event,
                            isFirst: isFirst,
                            isLast: isLast
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.timeline.event.\(event.id)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.timelineSection")
    }
}

// HomeTimelineHeader 首页时间线头部
// 核心职责：
// - 展示今天标题和年份角标
// - 保持查看全部入口与标题区分层
private struct HomeTimelineHeader: View {
    private var currentYearText: String {
        let year = Calendar.current.component(.year, from: Date())
        return "\(year)年"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s3) {
            HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s1) {
                Text("今天")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(currentYearText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 1)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("查看全部")
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// HomeTimelineRow 时间线事件行
private struct HomeTimelineRow: View {
    let event: HomeDashboardSnapshot.TimelineEvent
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            // 1. 左侧时间文字 (固定宽度对齐)
            Text(occurredTimeText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 44, alignment: .trailing)

            // 2. 时间线垂直连接线及圆点
            TimelineDotLine(isFirst: isFirst, isLast: isLast)

            // 3. 图标 (圆形或圆角矩形，根据类型有不同的配色方案)
            iconView
                .frame(width: 40, height: 40)
                .background(iconBgColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            // 4. 事件文字信息
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(event.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .layoutPriority(1)

            Spacer()

            // 5. 右侧特定修饰组件 (照片、变化值、箭头等)
            rightDecorationView
        }
        .padding(.top, isFirst ? 0 : MHBTheme.Spacing.s3)
        .padding(.bottom, MHBTheme.Spacing.s3)
    }

    private var occurredTimeText: String {
        if let occurredAt = event.occurredAt?.homeTimelineDate {
            return occurredAt.homeTimelineHourMinuteText
        }

        return event.occurredText.clockTimeText ?? event.occurredText
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(iconFgColor)
    }

    private var iconName: String {
        switch event.id {
        case "event-breakfast":
            return "fork.knife"
        case "event-weight":
            return "scalemass.fill"
        case "event-deworming":
            return "checkmark"
        case "event-walk":
            return "figure.walk"
        default:
            return "sparkles"
        }
    }

    private var iconFgColor: Color {
        switch event.id {
        case "event-breakfast":
            return Color(mhbHex: "E5A93C") // 暖金/黄色
        case "event-weight":
            return Color(mhbHex: "B794F4") // 紫色
        case "event-deworming":
            return Color(mhbHex: "63B3ED") // 蓝色
        case "event-walk":
            return Color(mhbHex: "F6AD55") // 橙色
        default:
            return .white
        }
    }

    private var iconBgColor: Color {
        iconFgColor.opacity(0.15)
    }

    @ViewBuilder
    private var rightDecorationView: some View {
        if event.id == "event-breakfast" {
            // 显示早餐食物图片
            Image("HomePetFoodBowl")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if event.id == "event-weight" {
            // 显示 +0.2 kg 变化值胶囊 (深绿背景 + 浅绿字体)
            MHBTagView(
                "+0.2 kg",
                style: .custom(
                    foreground: Color(mhbHex: "A3E635"),
                    background: Color(mhbHex: "4D7C0F").opacity(0.25)
                ),
                size: .medium
            )
        } else {
            // 显示灰色 chevron 箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

private extension String {
    var homeTimelineDate: Date? {
        let fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalSecondsFormatter.date(from: self) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }

    var clockTimeText: String? {
        guard let regex = try? NSRegularExpression(pattern: #"\b\d{1,2}:\d{2}\b"#) else {
            return nil
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              let swiftRange = Range(match.range, in: self) else {
            return nil
        }

        return String(self[swiftRange])
    }
}

private extension Date {
    var homeTimelineHourMinuteText: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}

// TimelineDotLine 时间线连接线及圆点
private struct TimelineDotLine: View {
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        ZStack {
            // 贯穿整行的垂直线，上下两段平分容器高度，保证圆点精确居中，且对齐行边缘
            VStack(spacing: 0) {
                if isFirst {
                    Color.clear
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }

                if isLast {
                    Color.clear
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            // 时间圆点
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 6, height: 6)
        }
        .frame(width: 16)
    }
}
