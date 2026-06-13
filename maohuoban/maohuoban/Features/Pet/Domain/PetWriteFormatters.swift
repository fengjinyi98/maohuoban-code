import Foundation

// PetWriteFormatters 宠物写入格式化工具
// 核心职责：
// - 统一宠物生日和事件时间请求格式
// - 避免表单视图直接持有格式化细节
enum PetWriteFormatters {
    private static let eventDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func birthdayString(from date: Date) -> String {
        date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
        )
    }

    static func occurredAtString(from date: Date) -> String {
        eventDateFormatter.string(from: date)
    }
}

extension PetSpecies {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .dog: "狗狗"
        case .cat: "猫咪"
        case .other: "其他"
        }
    }
}

extension PetSex {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .female: "妹妹"
        case .male: "弟弟"
        case .unknown: "未知"
        }
    }
}

extension PetEventKind {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .daily: "日常"
        case .health: "健康"
        case .merchant: "商家"
        case .trade: "交易"
        case .memorial: "纪念"
        }
    }
}

extension PetEventVisibility {
    var displayTitle: LocalizedStringResource {
        switch self {
        case .private: "仅自己"
        case .family: "家庭可见"
        case .publicTimeline: "公开"
        case .authorized: "授权可见"
        }
    }
}
