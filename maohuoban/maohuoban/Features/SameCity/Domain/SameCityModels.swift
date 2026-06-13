import Foundation

// SameCityHospitalList 同城医院列表
// 核心职责：
// - 承接后端按城市筛选的医院列表
// - 为首页预约和同城页共用医院选择数据
struct SameCityHospitalList: Decodable, Equatable {
    let city: String
    let hospitals: [SameCityHospital]
}

// SameCityHospital 同城医院摘要
// 核心职责：
// - 表达可预约医院的基础展示字段
// - 保留服务标签和认证状态供后续排序筛选扩展
struct SameCityHospital: Decodable, Equatable, Identifiable {
    let id: String
    let name: String
    let city: String
    let district: String?
    let address: String
    let phone: String?
    let serviceTags: [String]
    let verificationStatus: SameCityVerificationStatus

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case district
        case address
        case phone
        case serviceTags = "service_tags"
        case verificationStatus = "verification_status"
    }
}

// SameCityVerificationStatus 同城实体认证状态
// 核心职责：
// - 固定医院认证状态契约
// - 支持首页优先展示已认证医院
enum SameCityVerificationStatus: String, Codable, Equatable {
    case pending
    case verified
    case rejected
    case suspended
}

// HospitalAppointmentDraft 医院预约草稿
// 核心职责：
// - 承载用户提交医院预约所需字段
// - 将可选宠物和备注字段编码为后端契约
struct HospitalAppointmentDraft: Encodable, Equatable {
    let hospitalID: String
    let petID: String?
    let scheduledAt: String
    let reason: String
    let note: String

    enum CodingKeys: String, CodingKey {
        case hospitalID = "hospital_id"
        case petID = "pet_id"
        case scheduledAt = "scheduled_at"
        case reason
        case note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hospitalID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .hospitalID)
        try encodeOptionalText(petID ?? "", key: .petID, into: &container)
        try container.encode(scheduledAt, forKey: .scheduledAt)
        try container.encode(reason.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .reason)
        try encodeOptionalText(note, key: .note, into: &container)
    }

    private func encodeOptionalText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            try container.encodeNil(forKey: key)
        } else {
            try container.encode(trimmedValue, forKey: key)
        }
    }
}

// HospitalAppointment 医院预约结果
// 核心职责：
// - 承接后端创建预约后的稳定字段
// - 为后续消息沟通和医院记录回流保留关联 ID
struct HospitalAppointment: Decodable, Equatable, Identifiable {
    let id: String
    let ownerUserID: String
    let petID: String?
    let hospitalID: String
    let scheduledAt: String
    let reason: String
    let note: String?
    let status: HospitalAppointmentStatus

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case petID = "pet_id"
        case hospitalID = "hospital_id"
        case scheduledAt = "scheduled_at"
        case reason
        case note
        case status
    }
}

// HospitalAppointmentStatus 医院预约状态
// 核心职责：
// - 固定医院预约状态契约
// - 支持待确认、已确认、已取消和已完成流程扩展
enum HospitalAppointmentStatus: String, Codable, Equatable {
    case pending
    case confirmed
    case cancelled
    case completed
}
