import Foundation

// HospitalBookingFormatters 医院预约格式化工具
// 核心职责：
// - 将页面日期转换为后端时间字符串
// - 隔离预约表单和时间格式细节
enum HospitalBookingFormatters {
    static func scheduledAtString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
