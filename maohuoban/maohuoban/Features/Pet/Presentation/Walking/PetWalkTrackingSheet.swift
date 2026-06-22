import SwiftUI
import MaohuobanDesignSystem

// PetWalkTrackingSheet 遛弯记录系统 Sheet
// 核心职责：
// - 展示实时遛弯指标
// - 承载开始、暂停、继续和结束操作
struct PetWalkTrackingSheet: View {
    let store: PetWalkTrackingStore
    let petName: String?
    let petAvatarURL: URL?
    let petSex: PetRecordPetSex
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onFinish: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let metrics = store.displayMetrics(at: timeline.date)

            VStack(spacing: MHBTheme.Spacing.s4) {
                PetWalkExpandedMetrics(metrics: metrics)

                PetWalkSheetActionZone(
                    phase: store.phase,
                    canStart: store.canStartTracking,
                    onStart: onStart,
                    onPause: onPause,
                    onResume: onResume,
                    onFinish: onFinish
                )
            }
            .padding(.horizontal, MHBTheme.Spacing.s6)
            .padding(.top, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 32))
                .ignoresSafeArea()
        }
        .accessibilityIdentifier("pet.walkTracking.sheet")
    }
}

// PetWalkCollapsedSheetEntry Sheet 关闭后的迷你入口
// 核心职责：
// - 在系统 sheet 下拉关闭后保留当前记录摘要
// - 提供恢复 sheet 和快捷暂停/继续入口
struct PetWalkCollapsedSheetEntry: View {
    let store: PetWalkTrackingStore
    let petName: String?
    let petAvatarURL: URL?
    let petSex: PetRecordPetSex
    let bottomInset: CGFloat
    let onOpenSheet: () -> Void
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void

    var body: some View {
        VStack {
            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let metrics = store.displayMetrics(at: timeline.date)

                HStack(spacing: MHBTheme.Spacing.s3) {
                    Button(action: onOpenSheet) {
                        HStack(spacing: MHBTheme.Spacing.s3) {
                            PetWalkAvatarImage(
                                url: petAvatarURL,
                                petSex: petSex,
                                size: 40
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(PetWalkDisplayFormatters.distanceText(from: metrics.distanceKilometers))
                                    .font(MHBTheme.Typography.title.weight(.heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                                Text("\(petName ?? "毛伙伴") · \(PetWalkDisplayFormatters.elapsedText(from: metrics.elapsedSeconds))")
                                    .font(MHBTheme.Typography.caption.weight(.semibold))
                                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    PetWalkMiniControlButton(
                        phase: store.phase,
                        canStart: store.canStartTracking,
                        onStart: onStart,
                        onPause: onPause,
                        onResume: onResume
                    )
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(height: 84)
                .background(MHBTheme.ColorToken.cardSolid.color, in: .rect(cornerRadius: 32))
                .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 10)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.bottom, MHBTheme.Spacing.s5 + bottomInset)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier("pet.walkTracking.collapsedSheetEntry")
    }
}

// PetWalkExpandedMetrics Sheet 展开态指标
// 核心职责：
// - 展示当前距离主指标
// - 展示时长和热量两个辅助指标
private struct PetWalkExpandedMetrics: View {
    let metrics: PetWalkMetrics

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            VStack(spacing: MHBTheme.Spacing.s1) {
                Text(metrics.distanceKilometers, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("当前距离 (公里)")
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            HStack(spacing: 0) {
                PetWalkMetricItem(
                    title: "时长",
                    value: PetWalkDisplayFormatters.elapsedText(from: metrics.elapsedSeconds)
                )

                PetWalkMetricItem(
                    title: "千卡",
                    value: "\(metrics.estimatedCalories)"
                )
            }
        }
    }
}

// PetWalkMetricItem 遛弯指标项
// 核心职责：
// - 展示单个二级指标
// - 保持数字刷新时布局稳定
private struct PetWalkMetricItem: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            Text(value)
                .font(MHBTheme.Typography.title.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
    }
}

// PetWalkSheetActionZone Sheet 操作区
// 核心职责：
// - 根据会话状态展示可用操作
// - 维持展开态按钮布局稳定
private struct PetWalkSheetActionZone: View {
    let phase: PetWalkSessionPhase
    let canStart: Bool
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            switch phase {
            case .ready:
                PetWalkCapsuleControlButton(
                    title: "开始记录",
                    systemImage: "play.fill",
                    color: MHBTheme.ColorToken.success.color,
                    width: 200,
                    action: onStart
                )
                .disabled(!canStart)
                .opacity(canStart ? 1 : 0.55)
            case .tracking:
                PetWalkCapsuleControlButton(
                    title: "暂停记录",
                    systemImage: "pause.fill",
                    color: MHBTheme.ColorToken.warning.color,
                    width: 200,
                    action: onPause
                )
            case .paused:
                HStack(spacing: MHBTheme.Spacing.s4) {
                    PetWalkCapsuleControlButton(
                        title: "继续",
                        systemImage: "play.fill",
                        color: MHBTheme.ColorToken.success.color,
                        width: 140,
                        action: onResume
                    )

                    PetWalkCapsuleControlButton(
                        title: "结束遛弯",
                        systemImage: "stop.fill",
                        color: MHBTheme.ColorToken.danger.color,
                        width: 140,
                        action: onFinish
                    )
                }
            case .finished:
                PetWalkCapsuleControlButton(
                    title: "完成",
                    systemImage: "checkmark",
                    color: MHBTheme.ColorToken.success.color,
                    width: 200,
                    action: onFinish
                )
            }
        }
        .frame(height: 56)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: phase)
        .accessibilityIdentifier("pet.walkTracking.sheetActionZone")
    }
}

// PetWalkCapsuleControlButton 遛弯胶囊按钮
// 核心职责：
// - 提供 sheet 展开态的主操作按钮
// - 统一图标、文字和阴影样式
private struct PetWalkCapsuleControlButton: View {
    let title: LocalizedStringResource
    let systemImage: String
    let color: Color
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(MHBTheme.Typography.callout.weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: width, height: 56)
                .background(color, in: Capsule())
                .shadow(color: color.opacity(0.32), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// PetWalkMiniControlButton 迷你面板快捷按钮
// 核心职责：
// - 在 sheet 关闭后提供开始、暂停和继续快捷操作
// - 根据会话状态切换图标和颜色
private struct PetWalkMiniControlButton: View {
    let phase: PetWalkSessionPhase
    let canStart: Bool
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color, in: Circle())
                .shadow(color: color.opacity(0.32), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(phase == .ready && canStart == false)
        .opacity(phase == .ready && canStart == false ? 0.55 : 1)
    }

    private var action: () -> Void {
        switch phase {
        case .ready:
            onStart
        case .tracking:
            onPause
        case .paused:
            onResume
        case .finished:
            {}
        }
    }

    private var systemImage: String {
        switch phase {
        case .ready, .paused:
            "play.fill"
        case .tracking:
            "pause.fill"
        case .finished:
            "checkmark"
        }
    }

    private var color: Color {
        switch phase {
        case .ready, .paused, .finished:
            MHBTheme.ColorToken.success.color
        case .tracking:
            MHBTheme.ColorToken.warning.color
        }
    }
}

// PetWalkAvatarImage 遛弯宠物头像
// 核心职责：
// - 展示远程宠物头像或兜底爪印
// - 沿用记录页的性别边框识别规则
private struct PetWalkAvatarImage: View {
    let url: URL?
    let petSex: PetRecordPetSex
    let size: CGFloat

    var body: some View {
        MHBRemoteImage(url: url, contentMode: .fill) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MHBTheme.ColorToken.primaryBackground.color)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(petSex.borderColor, lineWidth: 1.5)
        }
    }
}

// PetWalkDisplayFormatters 遛弯展示格式化器
// 核心职责：
// - 统一距离和时长展示文本
// - 避免页面组件散落格式化规则
private enum PetWalkDisplayFormatters {
    static func distanceText(from kilometers: Double) -> String {
        String(format: "%.2f km", max(0, kilometers))
    }

    static func elapsedText(from seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
