import Foundation

// PetMedicalRecord 病历记录展示模型
// 核心职责：
// - 承载病历列表和详情页所需的医院发布病历数据
// - 将一次就诊的发布版健康档案和用户后续反馈聚合在同一记录下
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

}
