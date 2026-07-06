import Foundation

// SameCityRepository 同城仓库协议
// 核心职责：
// - 定义合作医院列表和预约 API
// - 隔离 HTTP 客户端和页面状态
protocol SameCityRepository {
    func listHospitals(
        city: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SameCityHospitalList>

    func bookHospitalAppointment(
        draft: HospitalAppointmentDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<HospitalAppointment>

    func cancelHospitalAppointment(
        appointmentID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<HospitalAppointment>
}

// DefaultSameCityRepository 默认同城仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 合作医院接口
// - 在请求中传递当前用户上下文
struct DefaultSameCityRepository: SameCityRepository {
    private let client: MHBHTTPClient

    init(
        client: MHBHTTPClient = MHBHTTPClient.authenticated()
    ) {
        self.client = client
    }

    func listHospitals(
        city: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SameCityHospitalList> {
        try await client.get(
            path: "/api/v1/same-city/hospitals",
            queryItems: [
                URLQueryItem(name: "city", value: city)
            ],
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func bookHospitalAppointment(
        draft: HospitalAppointmentDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<HospitalAppointment> {
        try await client.post(
            path: "/api/v1/same-city/hospital-appointments",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func cancelHospitalAppointment(
        appointmentID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<HospitalAppointment> {
        let trimmedAppointmentID = appointmentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppointmentID.isEmpty else {
            throw .business(
                code: "samecity.appointment_id_required",
                message: "预约不存在",
                statusCode: 400
            )
        }
        return try await client.post(
            path: "/api/v1/same-city/hospital-appointments/\(trimmedAppointmentID)/cancel",
            body: EmptySameCityRequestBody(),
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) throws(MHBAPIError) -> [String: String] {
        guard !currentUserID.isEmpty else {
            throw .business(
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录",
                statusCode: 401
            )
        }
        return ["x-maohuoban-user-id": currentUserID]
    }
}

// EmptySameCityRequestBody 空请求体
// 核心职责：
// - 为无字段 POST 契约提供 Encodable body
// - 避免业务层散写空字典
private struct EmptySameCityRequestBody: Encodable {}
