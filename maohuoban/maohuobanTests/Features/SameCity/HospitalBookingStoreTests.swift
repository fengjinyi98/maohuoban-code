import XCTest
@testable import maohuoban

// HospitalBookingStoreTests 医院预约 Store 测试
// 核心职责：
// - 验证同城医院加载和预约提交状态流
// - 固化当前用户上下文和输入校验行为
@MainActor
final class HospitalBookingStoreTests: XCTestCase {
    func testLoadHospitalsTransitionsToLoadedAndPassesContext() async {
        let repository = CapturingSameCityRepository()
        let list = SameCityHospitalList(
            city: "成都",
            hospitals: [
                SameCityHospital(
                    id: "hospital-1",
                    name: "瑞派宠物医院高新院区",
                    city: "成都",
                    district: "高新区",
                    address: "成都市高新区天府大道中段 88 号",
                    phone: "028-88880001",
                    serviceTags: ["体检", "疫苗"],
                    verificationStatus: .verified
                )
            ]
        )
        repository.listHospitalsResult = .success(
            MHBAPIResponse(
                success: true,
                code: "samecity.hospitals_loaded",
                message: "同城医院已加载",
                data: list
            )
        )
        let store = HospitalBookingStore(repository: repository)

        await store.loadHospitals(city: "成都", currentUserID: "user-1")

        XCTAssertEqual(store.phase, .loadedHospitals(list.hospitals))
        XCTAssertEqual(repository.receivedCity, "成都")
        XCTAssertEqual(repository.receivedListUserID, "user-1")
    }

    func testBookTransitionsToBookedAndPassesContext() async {
        let repository = CapturingSameCityRepository()
        let appointment = HospitalAppointment(
            id: "appointment-1",
            ownerUserID: "user-1",
            petID: "pet-1",
            hospitalID: "hospital-1",
            scheduledAt: "2026-06-15T09:30:00Z",
            reason: "基础体检",
            note: "希望安排上午到店",
            status: .pending
        )
        repository.bookResult = .success(
            MHBAPIResponse(
                success: true,
                code: "samecity.hospital_appointment_created",
                message: "医院预约已提交",
                data: appointment
            )
        )
        let store = HospitalBookingStore(repository: repository)

        await store.book(
            draft: HospitalAppointmentDraft(
                hospitalID: "hospital-1",
                petID: "pet-1",
                scheduledAt: "2026-06-15T09:30:00Z",
                reason: "基础体检",
                note: "希望安排上午到店"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(store.phase, .booked(appointment))
        XCTAssertEqual(store.successMessage, "医院预约已提交")
        XCTAssertEqual(repository.receivedBookUserID, "user-1")
        XCTAssertEqual(repository.receivedDraft?.hospitalID, "hospital-1")
    }

    func testBookWithoutUserContextFailsBeforeRepositoryCall() async {
        let repository = CapturingSameCityRepository()
        let store = HospitalBookingStore(repository: repository)

        await store.book(
            draft: HospitalAppointmentDraft(
                hospitalID: "hospital-1",
                petID: "pet-1",
                scheduledAt: "2026-06-15T09:30:00Z",
                reason: "基础体检",
                note: ""
            ),
            currentUserID: nil
        )

        XCTAssertEqual(store.phase, .failed("请先登录"))
        XCTAssertNil(repository.receivedDraft)
    }
}

// CapturingSameCityRepository 同城测试仓库
// 核心职责：
// - 捕获 Store 传入的查询和预约参数
// - 返回测试指定响应
@MainActor
private final class CapturingSameCityRepository: SameCityRepository {
    var listHospitalsResult: Result<MHBAPIResponse<SameCityHospitalList>, MHBAPIError> = .failure(.invalidResponse)
    var bookResult: Result<MHBAPIResponse<HospitalAppointment>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var receivedCity: String?
    private(set) var receivedListUserID: String?
    private(set) var receivedDraft: HospitalAppointmentDraft?
    private(set) var receivedBookUserID: String?

    func listHospitals(
        city: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SameCityHospitalList> {
        receivedCity = city
        receivedListUserID = currentUserID
        switch listHospitalsResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func bookHospitalAppointment(
        draft: HospitalAppointmentDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<HospitalAppointment> {
        receivedDraft = draft
        receivedBookUserID = currentUserID
        switch bookResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
