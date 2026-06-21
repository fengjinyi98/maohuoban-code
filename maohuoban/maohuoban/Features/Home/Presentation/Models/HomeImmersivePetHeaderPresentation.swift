import SwiftUI

// HomeImmersivePetHeaderPresentation 首页沉浸式头图展示模型
// 核心职责：
// - 将宠物基础字段转换为头图可直接渲染的展示文本
// - 统一维护头图性别图标、性别颜色和日期展示规则
struct HomeImmersivePetHeaderPresentation {
    let calendarDay: String
    let formattedDate: String
    let genderSymbolText: String?
    let genderColor: Color
    let worldDaysText: String
    let companionshipText: String

    static func make(
        pet: HomeDashboardSnapshot.PetHeroSummary,
        displayName: String,
        date: Date = Date()
    ) -> HomeImmersivePetHeaderPresentation {
        HomeImmersivePetHeaderPresentation(
            calendarDay: currentDayString(from: date),
            formattedDate: formattedDate(from: date),
            genderSymbolText: genderSymbolText(for: pet),
            genderColor: genderColor(for: pet),
            worldDaysText: "来到世界的第 \(worldDays(for: pet, date: date)) 天",
            companionshipText: "已陪伴 \(displayName) \(pet.companionshipDays ?? 365) 天"
        )
    }

    private static func genderSymbolText(for pet: HomeDashboardSnapshot.PetHeroSummary) -> String? {
        switch pet.sex {
        case .male:
            return "♂"
        case .female:
            return "♀"
        case .unknown:
            return nil
        }
    }

    private static func genderColor(for pet: HomeDashboardSnapshot.PetHeroSummary) -> Color {
        switch pet.sex {
        case .male:
            return maleColor
        case .female:
            return femaleColor
        case .unknown:
            return .white
        }
    }

    private static func currentDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private static func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM.dd"
        return formatter.string(from: date)
    }

    private static func worldDays(for pet: HomeDashboardSnapshot.PetHeroSummary, date: Date) -> Int {
        let birthday = pet.birthday ?? "2024-04-01"
        return daysSinceBirthday(birthday, referenceDate: date) ?? 0
    }

    private static func daysSinceBirthday(_ birthday: String, referenceDate: Date) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let birthDate = formatter.date(from: birthday) else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let birthToday = calendar.startOfDay(for: birthDate)

        let components = calendar.dateComponents([.day], from: birthToday, to: today)
        return components.day
    }

    private static let maleColor = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    private static let femaleColor = Color(red: 244 / 255, green: 63 / 255, blue: 94 / 255)
}
