import Foundation

// PetMedicalRecord 病历记录展示模型
// 核心职责：
// - 承载病历列表和详情页所需的前端 mock 数据
// - 将一次就诊的诊断、处置和后续追加记录聚合在同一病历下
struct PetMedicalRecord: Identifiable, Hashable {
    struct Update: Identifiable, Hashable {
        let id: String
        let title: String
        let occurredAtText: String
        let note: String
    }

    let id: String
    let petID: String
    var title: String
    var hospitalName: String
    var doctorName: String
    var occurredAtText: String
    var reason: String
    var diagnosis: String
    var treatment: String
    var medication: String
    var costText: String
    var note: String
    var attachmentTitles: [String]
    var updates: [Update]

    var subtitle: String {
        [hospitalName, diagnosis]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    mutating func appendUpdate(_ update: Update) {
        updates.insert(update, at: 0)
    }
}
