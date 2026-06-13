import Foundation
import SwiftUI
import MaohuobanDesignSystem

// HospitalBookingScreen 医院预约页面
// 核心职责：
// - 按城市读取可预约医院列表
// - 为当前宠物提交医院预约请求
struct HospitalBookingScreen: View {
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
                HospitalBookingIntroSection(city: resolvedCity)

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
                    }
                }
            }
            .padding(MHBTheme.Spacing.s4)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("预约医院")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .task(id: taskID) {
            guard petID != nil else { return }
            await store.loadHospitals(city: resolvedCity, currentUserID: currentUserID)
            selectFirstHospitalIfNeeded()
        }
        .accessibilityIdentifier("samecity.hospitalBooking.screen")
    }

    private var resolvedCity: String {
        let trimmedCity = (city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCity.isEmpty ? "成都" : trimmedCity
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

    private func selectFirstHospitalIfNeeded() {
        guard selectedHospitalID.isEmpty else { return }
        guard case .loadedHospitals(let hospitals) = store.phase else { return }
        selectedHospitalID = hospitals.first?.id ?? ""
    }
}
