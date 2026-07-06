import Foundation
import SwiftUI
import MaohuobanDesignSystem

// HospitalBookingScreen 医院预约页面
// 核心职责：
// - 读取开发验证阶段可预约 HIS 合作医院列表
// - 为当前宠物提交医院预约请求
struct HospitalBookingScreen: View {
    private static let validationHospitalCity = "毛伙伴市"

    let currentUserID: String?
    let petID: String?
    let city: String?
    let onBooked: () -> Void

    @State private var store = HospitalBookingStore()
    @State private var selectedHospitalID = ""
    @State private var scheduledAt = Date().addingTimeInterval(24 * 60 * 60)
    @State private var reason = "基础体检"
    @State private var note = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                HospitalBookingIntroSection()

                if petID == nil {
                    HospitalBookingUnavailableSection()
                } else {
                    HospitalBookingContentSection(
                        phase: store.phase,
                        selectedHospitalID: $selectedHospitalID,
                        scheduledAt: $scheduledAt,
                        reason: $reason,
                        note: $note,
                        isBusy: store.isBusy
                    ) {
                        Task { await submit() }
                    } onCancel: { appointment in
                        Task { await cancel(appointment) }
                    }
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("预约合作医院")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .task(id: taskID) {
            guard petID != nil else { return }
            await store.loadHospitals(city: resolvedCity, currentUserID: currentUserID)
            selectFirstHospitalIfNeeded()
        }
        .accessibilityIdentifier("samecity.hospitalBooking.screen")
        .onChange(of: store.toastMessage) { _, message in
            guard let message else { return }
            showToast(message: message, style: store.toastStyle)
        }
    }

    private var resolvedCity: String {
        Self.validationHospitalCity
    }

    private var taskID: String {
        "\(currentUserID ?? "anonymous")-\(petID ?? "no-pet")-\(resolvedCity)"
    }

    // submit 提交医院预约
    // 核心职责：
    // - 将页面表单转换为同城预约草稿
    // - 成功后通知首页刷新聚合快照
    private func submit() async {
        await store.book(
            draft: HospitalAppointmentDraft(
                hospitalID: selectedHospitalID,
                petID: petID,
                scheduledAt: HospitalBookingFormatters.scheduledAtString(from: scheduledAt),
                reason: reason,
                note: note
            ),
            currentUserID: currentUserID
        )
        if case .booked = store.phase {
            onBooked()
        }
    }

    // cancel 取消医院预约
    // 核心职责：
    // - 调用 Store 触发真实后端取消
    // - 成功后通知首页刷新聚合快照
    private func cancel(_ appointment: HospitalAppointment) async {
        await store.cancel(appointmentID: appointment.id, currentUserID: currentUserID)
        if case .booked(let appointment) = store.phase, appointment.status == .cancelled {
            onBooked()
        }
    }

    private func showToast(message: String, style: HospitalBookingToastStyle) {
        switch style {
        case .success:
            MHBToastPresenter().success(message)
        case .danger:
            MHBToastPresenter().danger(message)
        }
    }

    private func selectFirstHospitalIfNeeded() {
        guard selectedHospitalID.isEmpty else { return }
        guard case .loadedHospitals(let hospitals) = store.phase else { return }
        selectedHospitalID = hospitals.first?.id ?? ""
    }
}
