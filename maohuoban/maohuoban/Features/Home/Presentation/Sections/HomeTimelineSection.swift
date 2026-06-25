import Foundation
import SwiftUI
import MaohuobanDesignSystem

// HomeTimelineSection 最近时间线模块
// 核心职责：
// - 展示当前宠物今天记录的关键时间线事件
// - 呈现高对比度、呼吸感强的磨砂玻璃时间轴卡片
struct HomeTimelineSection: View {
    let events: [HomeDashboardSnapshot.TimelineEvent]
    let historyRoute: HomeRoute

    private var displayedEvents: [HomeDashboardSnapshot.TimelineEvent] {
        Array(events.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HomeTimelineHeader(historyRoute: historyRoute)

            // 时间轴垂直列表
            VStack(spacing: 0) {
                ForEach(Array(displayedEvents.enumerated()), id: \.element.id) { index, event in
                    let isFirst = index == 0
                    let isLast = index == displayedEvents.count - 1

                    NavigationLink(value: HomeRoute.petRecordDetail(event.recordDetailRoute)) {
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
    let historyRoute: HomeRoute

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

            NavigationLink(value: historyRoute) {
                HStack(spacing: 4) {
                    Text("查看全部")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
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
        switch event.timelineSemantic {
        case .feeding:
            return "fork.knife"
        case .poopNormal:
            return "checkmark.seal.fill"
        case .energyNormal:
            return "face.smiling"
        case .appetiteNormal:
            return "takeoutbag.and.cup.and.straw.fill"
        case .weight:
            return "scalemass.fill"
        case .deworming:
            return "checkmark"
        case .walk:
            return "figure.walk"
        case .vaccine:
            return "syringe.fill"
        case .abnormal:
            return "cross.case.fill"
        case .clinicVisit:
            return "stethoscope"
        case .unsupported:
            return "sparkles"
        }
    }

    private var iconFgColor: Color {
        switch event.timelineSemantic {
        case .feeding:
            return Color(mhbHex: "0093DD")
        case .poopNormal:
            return MHBTheme.ColorToken.teal.color
        case .energyNormal:
            return MHBTheme.ColorToken.primary.color
        case .appetiteNormal:
            return MHBTheme.ColorToken.warning.color
        case .weight:
            return Color(mhbHex: "B794F4")
        case .deworming, .vaccine:
            return Color(mhbHex: "63B3ED")
        case .walk:
            return Color(mhbHex: "F6AD55")
        case .abnormal:
            return MHBTheme.ColorToken.danger.color
        case .clinicVisit:
            return MHBTheme.ColorToken.primary.color
        case .unsupported:
            return .white
        }
    }

    private var iconBgColor: Color {
        iconFgColor.opacity(0.15)
    }

    @ViewBuilder
    private var rightDecorationView: some View {
        switch event.timelineSemantic {
        case .feeding:
            Image("HomePetFoodBowl")
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .weight:
            MHBTagView(
                "+0.2 kg",
                style: .custom(
                    foreground: Color(mhbHex: "A3E635"),
                    background: Color(mhbHex: "4D7C0F").opacity(0.25)
                ),
                size: .medium
            )
        default:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// HomeTimelineRecordSemantic 首页时间线记录语义
// 核心职责：
// - 将 mock ID、真实记录标题和摘要收敛为稳定详情路由
// - 避免后端生成记录 ID 后快速事实误入未接入占位页
private enum HomeTimelineRecordSemantic {
    case feeding
    case poopNormal
    case energyNormal
    case appetiteNormal
    case weight
    case deworming
    case walk
    case vaccine
    case abnormal
    case clinicVisit
    case unsupported
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

private extension HomeDashboardSnapshot.TimelineEvent {
    var recordDetailRoute: PetRecordDetailRoute {
        switch timelineSemantic {
        case .feeding:
            return .feeding(recordID: id)
        case .poopNormal:
            return .quickFact(.poopNormal)
        case .energyNormal:
            return .quickFact(.energyNormal)
        case .appetiteNormal:
            return .quickFact(.appetiteNormal)
        case .weight:
            return .weight(recordID: id)
        case .deworming:
            return .deworming(recordID: id)
        case .walk:
            return .walk(recordID: id)
        case .vaccine:
            return .vaccine(recordID: id)
        case .abnormal:
            return .abnormal(recordID: id)
        case .clinicVisit:
            return .clinicVisit(recordID: id)
        case .unsupported:
            return .unsupported(recordID: id)
        }
    }

    var timelineSemantic: HomeTimelineRecordSemantic {
        switch id {
        case "event-feeding", "record-2026-06-feeding":
            return .feeding
        case "event-quick-poop-normal", "record-2026-06-poop-normal":
            return .poopNormal
        case "event-quick-energy-normal", "record-2026-06-energy-normal":
            return .energyNormal
        case "event-quick-appetite-normal", "record-2026-05-appetite":
            return .appetiteNormal
        case "event-weight", "record-2026-06-weight":
            return .weight
        case "event-deworming", "record-2026-06-deworming":
            return .deworming
        case "event-walk", "record-2026-05-walk":
            return .walk
        case "event-abnormal", "record-2026-06-abnormal":
            return .abnormal
        case "record-2026-04-hospital":
            return .clinicVisit
        default:
            return inferredTimelineSemantic
        }
    }

    private var inferredTimelineSemantic: HomeTimelineRecordSemantic {
        let combinedText = "\(title) \(subtitle)"

        if title.contains("喂") || subtitle.contains("喂食") {
            return .feeding
        }

        if combinedText.contains("便便") || combinedText.contains("粪便") || combinedText.contains("排便") {
            return .poopNormal
        }

        if combinedText.contains("精神") || combinedText.contains("活力") {
            return .energyNormal
        }

        if combinedText.contains("食欲") {
            return .appetiteNormal
        }

        switch eventKind {
        case .weight:
            return .weight
        case .deworming:
            return .deworming
        case .vaccine:
            return .vaccine
        case .health where combinedText.contains("异常"):
            return .abnormal
        case .health where combinedText.contains("就诊") || combinedText.contains("医院"):
            return .clinicVisit
        case .daily where combinedText.contains("散步") || combinedText.contains("遛弯"):
            return .walk
        case .daily, .health, .merchant:
            return .unsupported
        }
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
