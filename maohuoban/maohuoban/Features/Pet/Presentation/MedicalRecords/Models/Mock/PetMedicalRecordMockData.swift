import Foundation

// PetMedicalRecordMockData 病历记录前端样例数据
// 核心职责：
// - 为病历列表和详情页提供稳定 mock 数据
// - 覆盖就诊、复查和处方场景
enum PetMedicalRecordMockData {
    static func records(for pets: [PetRecordSwitchPet]) -> [PetMedicalRecord] {
        let petID = pets.first?.id ?? "pet-medical-current"
        return [
            PetMedicalRecord(
                id: "medical-2026-06-gastro",
                petID: petID,
                title: "急性肠胃炎复诊",
                hospitalName: "瑞派宠物医院",
                doctorName: "林医生",
                occurredAtText: "2026年6月18日 15:30",
                reason: "呕吐两次，软便，精神一般",
                diagnosis: "急性肠胃炎",
                treatment: "皮下注射止吐针，建议少量多餐观察 48 小时",
                medication: "益生菌 1 包/日，连用 5 天",
                costText: "328 元",
                note: "医生建议若继续呕吐需要复查血常规和胰腺指标。",
                attachmentTitles: ["处方单", "缴费单"],
                updates: [
                    PetMedicalRecord.Update(
                        id: "medical-2026-06-gastro-update-1",
                        title: "恢复观察",
                        occurredAtText: "2026年6月19日 20:10",
                        note: "晚间食欲恢复，未继续呕吐，便便偏软。"
                    )
                ]
            ),
            PetMedicalRecord(
                id: "medical-2026-05-skin",
                petID: petID,
                title: "皮肤瘙痒检查",
                hospitalName: "安心动物医院",
                doctorName: "周医生",
                occurredAtText: "2026年5月26日 10:20",
                reason: "后颈抓挠频繁，局部掉毛",
                diagnosis: "疑似过敏性皮炎",
                treatment: "伍德灯检查阴性，局部清洁护理",
                medication: "外用喷剂每日 2 次，连续 7 天",
                costText: "186 元",
                note: "建议同步排查近期新食物和清洁用品。",
                attachmentTitles: ["检查单"],
                updates: []
            )
        ]
    }
}
