import SwiftUI

// PetPreventiveCareRecordReminderSection 疫苗驱虫提醒信息区
// 核心职责：
// - 展示提醒开关状态、提醒日期和距离到期
// - 让用户理解列表与首页到期提示来源
struct PetPreventiveCareRecordReminderSection: View {
    let rows: [PetPreventiveCareRecordDetailPresentation.InfoRow]

    var body: some View {
        PetPreventiveCareRecordDetailSection(title: "下次提醒") {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    PetPreventiveCareRecordInfoRow(title: row.title, value: row.value)

                    if row.id != rows.last?.id {
                        PetPreventiveCareRecordDivider()
                    }
                }
            }
        }
    }
}
