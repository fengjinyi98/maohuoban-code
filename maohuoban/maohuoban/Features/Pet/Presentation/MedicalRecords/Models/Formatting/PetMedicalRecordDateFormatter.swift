import Foundation

// PetMedicalRecordDateFormatter 病历记录日期格式化器
// 核心职责：
// - 统一医院病历时间展示
// - 避免列表和详情散写日期格式
enum PetMedicalRecordDateFormatter {
    static func text(from date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month(.wide)
                .day()
                .hour()
                .minute()
        )
    }
}
