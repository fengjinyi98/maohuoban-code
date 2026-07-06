import SwiftUI
import MaohuobanDesignSystem

// HospitalBookingContentSection 医院预约内容区
// 核心职责：
// - 根据 Store 阶段切换加载、表单、成功和失败态
// - 将提交事件转发给页面动作
struct HospitalBookingContentSection: View {
    let phase: HospitalBookingPhase
    @Binding var selectedHospitalID: String
    @Binding var scheduledAt: Date
    @Binding var reason: String
    @Binding var note: String
    let isBusy: Bool
    let onSubmit: () -> Void

    var body: some View {
        switch phase {
        case .idle, .loadingHospitals:
            HospitalBookingLoadingSection()
        case .loadedHospitals(let hospitals):
            HospitalBookingFormSection(
                hospitals: hospitals,
                selectedHospitalID: $selectedHospitalID,
                scheduledAt: $scheduledAt,
                reason: $reason,
                note: $note,
                isBusy: isBusy,
                onSubmit: onSubmit
            )
        case .booking:
            HospitalBookingSubmittingSection()
        case .booked:
            HospitalBookingSuccessSection()
        case .failed(let message):
            HospitalBookingFailedSection(message: message)
        }
    }
}

// HospitalBookingFormSection 医院预约表单
// 核心职责：
// - 收集医院、时间、原因和备注
// - 控制预约提交按钮可用状态
struct HospitalBookingFormSection: View {
    let hospitals: [SameCityHospital]
    @Binding var selectedHospitalID: String
    @Binding var scheduledAt: Date
    @Binding var reason: String
    @Binding var note: String
    let isBusy: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            if hospitals.isEmpty {
                HospitalBookingEmptySection()
            } else {
                Picker("医院", selection: $selectedHospitalID) {
                    ForEach(hospitals) { hospital in
                        Text(hospital.name).tag(hospital.id)
                    }
                }
                .pickerStyle(.menu)
                .padding(MHBTheme.Spacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .accessibilityIdentifier("samecity.hospitalBooking.hospitalPicker")

                HospitalBookingSelectedHospitalSection(
                    hospital: hospitals.first { $0.id == selectedHospitalID }
                )

                DatePicker(
                    "预约时间",
                    selection: $scheduledAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                SameCityTextField(title: "预约原因", text: $reason, prompt: "例如 基础体检")
                SameCityTextField(title: "备注", text: $note, prompt: "例如 希望安排上午到店")

                Button(action: onSubmit) {
                    Label("提交预约", systemImage: "calendar.badge.plus")
                        .font(MHBTheme.Typography.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    selectedHospitalID.isEmpty ||
                    reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    isBusy
                )
                .accessibilityIdentifier("samecity.hospitalBooking.submit")
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// HospitalBookingSelectedHospitalSection 已选医院摘要
// 核心职责：
// - 展示当前选中合作医院地址和 HIS 能力
// - 帮助用户确认预约对象
struct HospitalBookingSelectedHospitalSection: View {
    let hospital: SameCityHospital?

    var body: some View {
        if let hospital {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(hospital.address)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                Text(hospital.serviceTags.formatted())
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                HStack(spacing: MHBTheme.Spacing.s2) {
                    if hospital.hisEnabled {
                        HospitalBookingCapabilityLabel(title: "已接入 HIS", systemImage: "checkmark.seal.fill")
                    }
                    if hospital.medicalRecordReturnEnabled {
                        HospitalBookingCapabilityLabel(title: "支持病历回流", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
    }
}

// HospitalBookingCapabilityLabel 合作医院能力标签
// 核心职责：
// - 展示后端下发的 HIS 合作能力
// - 保持预约表单内的轻量状态反馈
struct HospitalBookingCapabilityLabel: View {
    let title: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(MHBTheme.Typography.caption)
            .foregroundStyle(MHBTheme.ColorToken.success.color)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .background(MHBTheme.ColorToken.success.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
    }
}

// SameCityTextField 同城文本输入行
// 核心职责：
// - 复用同城页面的标签和输入样式
// - 保持表单字段视觉一致
struct SameCityTextField: View {
    let title: LocalizedStringResource
    @Binding var text: String
    let prompt: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            TextField(title, text: $text, prompt: Text(prompt), axis: .vertical)
                .lineLimit(1...3)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
    }
}
