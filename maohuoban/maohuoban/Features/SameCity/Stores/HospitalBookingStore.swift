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
    var toastMessage: String?
    var toastStyle: HospitalBookingToastStyle = .success

    var isBusy: Bool {
        phase == .loadingHospitals || phase == .booking || phase == .cancelling
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
        toastMessage = nil
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
        toastMessage = nil
        do {
            let response = try await repository.bookHospitalAppointment(
                draft: draft,
                currentUserID: currentUserID
            )
            guard let appointment = response.data else {
                toastStyle = .danger
                phase = .failed("预约结果为空")
                return
            }
            toastStyle = .success
            toastMessage = response.message
            phase = .booked(appointment)
        } catch {
            toastStyle = .danger
            toastMessage = error.toastMessage
            phase = .failed(error.toastMessage)
        }
    }

    func cancel(
        appointmentID: String,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            toastStyle = .danger
            toastMessage = "请先登录"
            phase = .failed("请先登录")
            return
        }
        let trimmedAppointmentID = appointmentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppointmentID.isEmpty else {
            toastStyle = .danger
            toastMessage = "预约不存在"
            phase = .failed("预约不存在")
            return
        }
        guard phase != .cancelling else { return }

        phase = .cancelling
        toastMessage = nil
        do {
            let response = try await repository.cancelHospitalAppointment(
                appointmentID: trimmedAppointmentID,
                currentUserID: currentUserID
            )
            guard let appointment = response.data else {
                toastStyle = .danger
                toastMessage = "取消结果为空"
                phase = .failed("取消结果为空")
                return
            }
            toastStyle = .success
            toastMessage = response.message
            phase = .booked(appointment)
        } catch {
            toastStyle = .danger
            toastMessage = error.toastMessage
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
    case cancelling
    case booked(HospitalAppointment)
    case failed(String)
}

// HospitalBookingToastStyle 医院预约 Toast 样式
// 核心职责：
// - 表达最近一次预约操作反馈的视觉语义
// - 避免页面根据 phase 写入时序推断 Toast 成败
enum HospitalBookingToastStyle: Equatable {
    case success
    case danger
}
