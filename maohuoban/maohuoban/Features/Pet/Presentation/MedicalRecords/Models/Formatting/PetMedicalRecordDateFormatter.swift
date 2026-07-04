import Foundation

// PetMedicalRecordDateFormatter 病历记录日期格式化器
// 核心职责：
// - 统一病历 mock 表单保存后的日期展示
// - 避免表单和列表散写日期格式
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
