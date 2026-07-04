import Foundation
import SwiftUI
import MaohuobanDesignSystem

// PantryItemFeedingTimelineRow 物品喂食时间线行
// 核心职责：
// - 展示单条喂食事件标题、宠物和份量
// - 保持时间线行与首页记录风格接近
struct PantryItemFeedingTimelineRow: View {
    let entry: FoodInventoryFeedingTimelineEntry
    let isFirst: Bool
    let isLast: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
                Text(occurredTimeText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 44, alignment: .trailing)

                MHBTimelineDotLine(
                    isFirst: isFirst,
                    isLast: isLast,
                    lineColor: MHBTheme.ColorToken.labelTertiary.color.opacity(0.22),
                    dotColor: MHBTheme.ColorToken.labelTertiary.color.opacity(0.55)
                )

                Image(systemName: "fork.knife")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(mhbHex: "0093DD"))
                    .frame(width: 40, height: 40)
                    .background(Color(mhbHex: "0093DD").opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text("\(entry.petName) · \(entry.amountText)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)

                    if let summary = entry.summary, !summary.isEmpty {
                        Text(summary)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                            .lineLimit(2)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: MHBTheme.Spacing.s2)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(.top, isFirst ? 0 : MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pantry.itemDetail.feedingTimeline.\(entry.eventID)")
    }

    private var occurredTimeText: String {
        if let date = MHBUTCDateDisplayFormatter.date(fromUTCString: entry.occurredAt) {
            return date.pantryTimelineHourMinuteText
        }

        return entry.occurredAt.pantryClockTimeText ?? entry.occurredAt
    }
}

private extension String {
    var pantryClockTimeText: String? {
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
    var pantryTimelineHourMinuteText: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}
