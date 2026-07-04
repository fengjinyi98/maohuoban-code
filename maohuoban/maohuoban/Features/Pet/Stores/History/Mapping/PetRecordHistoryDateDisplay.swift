import Foundation

// PetRecordHistoryDateDisplay 记录历史日期展示
// 核心职责：
// - 将后端 UTC 时间转换为历史列表的年月日时间文案
// - 在解析失败时提供稳定兜底展示
struct PetRecordHistoryDateDisplay {
    let yearText: String
    let monthText: String
    let dateText: String
    let timeText: String

    init(date: Date?, fallback: String) {
        guard let date else {
            self.yearText = String(fallback.prefix(4))
            self.monthText = "--月"
            self.dateText = "--/--"
            self.timeText = "--:--"
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        self.yearText = components.year.map(String.init) ?? "--"
        self.monthText = components.month.map { "\($0)月" } ?? "--月"
        self.dateText = Self.twoDigitText(month: components.month, day: components.day)
        self.timeText = Self.twoDigitText(hour: components.hour, minute: components.minute)
    }

    private static func twoDigitText(month: Int?, day: Int?) -> String {
        guard let month, let day else { return "--/--" }
        return String(format: "%02d/%02d", month, day)
    }

    private static func twoDigitText(hour: Int?, minute: Int?) -> String {
        guard let hour, let minute else { return "--:--" }
        return String(format: "%02d:%02d", hour, minute)
    }
}
