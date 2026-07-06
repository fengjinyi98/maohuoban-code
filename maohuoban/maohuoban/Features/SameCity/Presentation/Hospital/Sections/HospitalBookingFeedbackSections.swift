import SwiftUI
import MaohuobanDesignSystem

// HospitalBookingLoadingSection 医院列表加载态
// 核心职责：
// - 展示医院列表加载过程
// - 保持页面结构稳定
struct HospitalBookingLoadingSection: View {
    var body: some View {
        HospitalBookingMessageSection(
            systemImage: "hourglass",
            title: "正在读取合作医院",
            message: "请稍候",
            color: MHBTheme.ColorToken.primary.color,
            showsProgress: true
        )
    }
}

// HospitalBookingSubmittingSection 医院预约提交态
// 核心职责：
// - 展示预约提交过程
// - 阻止用户重复提交
struct HospitalBookingSubmittingSection: View {
    var body: some View {
        HospitalBookingMessageSection(
            systemImage: "calendar.badge.clock",
            title: "正在提交预约",
            message: "医院确认前预约状态为待确认",
            color: MHBTheme.ColorToken.primary.color,
            showsProgress: true
        )
    }
}

// HospitalBookingEmptySection 医院列表空态
// 核心职责：
// - 展示当前城市没有 HIS 合作医院
// - 明确非合作医院应走诊前资料包辅助路径
struct HospitalBookingEmptySection: View {
    var body: some View {
        HospitalBookingMessageSection(
            systemImage: "building.2.crop.circle",
            title: "暂无合作医院",
            message: "当前城市暂未开通合作医院，可先生成诊前资料包带去线下就医",
            color: MHBTheme.ColorToken.warning.color
        )
    }
}

// HospitalBookingUnavailableSection 缺少宠物上下文提示
// 核心职责：
// - 展示缺少当前宠物时的不可预约状态
// - 阻止创建无主体预约
struct HospitalBookingUnavailableSection: View {
    var body: some View {
        HospitalBookingMessageSection(
            systemImage: "pawprint.circle",
            title: "请先选择宠物",
            message: "合作医院预约需要绑定当前宠物档案",
            color: MHBTheme.ColorToken.warning.color
        )
    }
}

// HospitalBookingSuccessSection 医院预约成功态
// 核心职责：
// - 展示已创建的预约状态
// - 提示后续医院确认流程
struct HospitalBookingSuccessSection: View {
    var body: some View {
        HospitalBookingMessageSection(
            systemImage: "checkmark.seal.fill",
            title: "预约已提交",
            message: "当前状态为待确认，合作医院确认后会进入后续沟通",
            color: MHBTheme.ColorToken.success.color
        )
    }
}

// HospitalBookingFailedSection 医院预约失败态
// 核心职责：
// - 展示医院列表或预约提交失败原因
// - 保持错误反馈在当前页面内呈现
struct HospitalBookingFailedSection: View {
    let message: String

    var body: some View {
        HospitalBookingMessageSection(
            systemImage: "exclamationmark.triangle.fill",
            title: "暂时无法预约",
            message: message,
            color: MHBTheme.ColorToken.danger.color
        )
    }
}

// HospitalBookingMessageSection 医院预约消息卡
// 核心职责：
// - 统一加载、空态、成功和失败反馈
// - 复用 DesignSystem 视觉 token
struct HospitalBookingMessageSection: View {
    let systemImage: String
    let title: LocalizedStringResource
    let message: String
    let color: Color
    var showsProgress = false

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            if showsProgress {
                ProgressView()
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(MHBTheme.Spacing.s6)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
