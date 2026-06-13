import Foundation
import Observation

// HospitalBookingStore 医院预约状态模型
// 核心职责：
// - 管理同城医院列表加载状态
// - 承接医院预约提交、输入校验和成功反馈
@MainActor
@Observable
final class HospitalBookingStore {
    var phase: HospitalBookingPhase = .idle
    var successMessage: String?

    var isBusy: Bool {
        phase == .loadingHospitals || phase == .booking
    }

    private let repository: SameCityRepository

    init(repository: SameCityRepository = DefaultSameCityRepository()) {
        self.repository = repository
    }

    func loadHospitals(city: String, currentUserID: String?) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else {
            phase = .failed("城市信息为空")
            return
        }
        guard phase != .loadingHospitals else { return }

        phase = .loadingHospitals
        successMessage = nil
        do {
            let response = try await repository.listHospitals(
                city: trimmedCity,
                currentUserID: currentUserID
            )
            guard let list = response.data else {
                phase = .failed("医院列表为空")
                return
            }
            phase = .loadedHospitals(list.hospitals)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func book(
        draft: HospitalAppointmentDraft,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard !draft.hospitalID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请选择医院")
            return
        }
        guard !draft.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入预约原因")
            return
        }
        guard phase != .booking else { return }

        phase = .booking
        successMessage = nil
        do {
            let response = try await repository.bookHospitalAppointment(
                draft: draft,
                currentUserID: currentUserID
            )
            guard let appointment = response.data else {
                phase = .failed("预约结果为空")
                return
            }
            successMessage = response.message
            phase = .booked(appointment)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }
}

// HospitalBookingPhase 医院预约阶段
// 核心职责：
// - 表达医院列表加载、预约提交、成功和失败状态
// - 支持页面基于单一状态渲染反馈
enum HospitalBookingPhase: Equatable {
    case idle
    case loadingHospitals
    case loadedHospitals([SameCityHospital])
    case booking
    case booked(HospitalAppointment)
    case failed(String)
}
