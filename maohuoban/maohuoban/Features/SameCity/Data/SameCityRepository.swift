import Foundation

// SameCityRepository 同城仓库协议
// 核心职责：
// - 定义同城医院列表和预约 API
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
}

// DefaultSameCityRepository 默认同城仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 同城接口
// - 在请求中传递当前用户上下文
struct DefaultSameCityRepository: SameCityRepository {
    private let client: MHBHTTPClient

    init(client: MHBHTTPClient = MHBHTTPClient()) {
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
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func bookHospitalAppointment(
        draft: HospitalAppointmentDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<HospitalAppointment> {
        try await client.post(
            path: "/api/v1/same-city/hospital-appointments",
            body: draft,
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) -> [String: String] {
        ["x-maohuoban-user-id": currentUserID]
    }
}
