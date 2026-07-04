import SwiftUI

// PetPreventiveCareRecordInfoSection 疫苗驱虫记录信息区
// 核心职责：
// - 展示类型、名称、完成日期和执行方式
// - 使用键值行保持信息可扫描
struct PetPreventiveCareRecordInfoSection: View {
    let rows: [PetPreventiveCareRecordDetailPresentation.InfoRow]

    var body: some View {
        PetPreventiveCareRecordDetailSection(title: "记录信息") {
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
