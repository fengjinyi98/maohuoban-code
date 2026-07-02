import Foundation

// MHBPhotoGridScrollDateFormatter 照片网格滚动日期格式化器
// 核心职责：
// - 将照片创建时间转换为滚动浮层展示文案
// - 统一今天、昨天、星期、月日和年月日的分层规则
final class MHBPhotoGridScrollDateFormatter {
    private let calendar: Calendar
    private let monthDayFormatter: DateFormatter
    private let yearMonthDayFormatter: DateFormatter

    init(calendar: Calendar = .current) {
        self.calendar = calendar

        let locale = Locale(identifier: "zh_Hans_CN")

        self.monthDayFormatter = DateFormatter()
        self.monthDayFormatter.locale = locale
        self.monthDayFormatter.calendar = calendar
        self.monthDayFormatter.dateFormat = "M月d日"

        self.yearMonthDayFormatter = DateFormatter()
        self.yearMonthDayFormatter.locale = locale
        self.yearMonthDayFormatter.calendar = calendar
        self.yearMonthDayFormatter.dateFormat = "yyyy年M月d日"
    }

    func title(for date: Date, now: Date = Date()) -> String {
        if calendar.isDateInToday(date) {
            return "今天"
        }

        if calendar.isDateInYesterday(date) {
            return "昨天"
        }

        if isDateInRecentWeek(date, now: now) {
            return weekdayTitle(for: date)
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return monthDayFormatter.string(from: date)
        }

        return yearMonthDayFormatter.string(from: date)
    }

    private func isDateInRecentWeek(_ date: Date, now: Date) -> Bool {
        let dateStart = calendar.startOfDay(for: date)
        let nowStart = calendar.startOfDay(for: now)
        guard let days = calendar.dateComponents([.day], from: dateStart, to: nowStart).day else {
            return false
        }
        return days >= 2 && days < 7
    }

    private func weekdayTitle(for date: Date) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1:
            return "星期日"
        case 2:
            return "星期一"
        case 3:
            return "星期二"
        case 4:
            return "星期三"
        case 5:
            return "星期四"
        case 6:
            return "星期五"
        default:
            return "星期六"
        }
    }
}
