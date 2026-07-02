import SwiftUI
import MaohuobanDesignSystem

// PetWalkHistoryDetailScreen 遛弯记录详情页
// 核心职责：
// - 展示单次遛弯的轨迹播放和基础摘要
// - 承载历史记录列表点击后的详情查看
struct PetWalkHistoryDetailScreen: View {
    let record: PetWalkHistoryRecord
    let petName: String
    let petAvatarURL: URL?
    let petSex: PetRecordPetSex

    @State private var playbackProgress = 0.0
    @State private var isPlaying = false
    @State private var playbackRunID = 0

    private let playbackDurationSeconds: Double = 8
    private let floatingSummaryHeight: CGFloat = 116
    private let playbackControlsHeight: CGFloat = 68

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            let floatingCardBottomPadding = MHBTheme.Spacing.s5 + bottomInset
            let playbackControlsBottomPadding = floatingSummaryHeight + floatingCardBottomPadding + MHBTheme.Spacing.s4
            let routeBottomInset = playbackControlsBottomPadding + playbackControlsHeight + MHBTheme.Spacing.s5

            ZStack(alignment: .bottom) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                PetWalkHistoryDetailPlaybackMap(
                    routePreview: record.routePreview,
                    progress: playbackProgress,
                    petAvatarURL: petAvatarURL,
                    petSex: petSex,
                    elapsedText: playbackElapsedText,
                    isPlaying: isPlaying,
                    routeBottomInset: routeBottomInset,
                    controlsBottomPadding: playbackControlsBottomPadding,
                    onTogglePlayback: togglePlayback
                )
                .frame(width: proxy.size.width, height: proxy.size.height + bottomInset)
                .ignoresSafeArea(.container, edges: [.top, .bottom])

                PetWalkHistoryDetailFloatingSummary(
                    title: record.detailTitle(petName: petName),
                    timeText: record.timeRangeText,
                    distanceText: record.distanceText,
                    durationText: record.durationText,
                    bottomInset: bottomInset
                )
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .navigationTitle("遛弯详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: playbackRunID) {
            await runPlaybackIfNeeded()
        }
        .accessibilityIdentifier("pet.walkHistory.detail.screen")
    }

    private var playbackElapsedText: String {
        let totalSeconds = max(1, record.durationMinutes * 60)
        let elapsedSeconds = Int((Double(totalSeconds) * playbackProgress).rounded())
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func togglePlayback() {
        playbackProgress = 0
        isPlaying = true
        playbackRunID += 1
    }

    private func runPlaybackIfNeeded() async {
        guard isPlaying else { return }

        let frameCount = 240
        for frame in 0...frameCount {
            if Task.isCancelled { return }
            let progress = Double(frame) / Double(frameCount)

            await MainActor.run {
                playbackProgress = progress
            }

            try? await Task.sleep(nanoseconds: UInt64(playbackDurationSeconds * 1_000_000_000 / Double(frameCount)))
        }

        await MainActor.run {
            playbackProgress = 1
            isPlaying = false
        }
    }
}

// PetWalkHistoryDetailPlaybackMap 遛弯详情轨迹播放地图区
// 核心职责：
// - 绘制路线播放进度
// - 展示播放控制舱和宠物位置 marker
private struct PetWalkHistoryDetailPlaybackMap: View {
    let routePreview: PetWalkHistoryRoutePreview
    let progress: Double
    let petAvatarURL: URL?
    let petSex: PetRecordPetSex
    let elapsedText: String
    let isPlaying: Bool
    let routeBottomInset: CGFloat
    let controlsBottomPadding: CGFloat
    let onTogglePlayback: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            PetWalkHistoryDetailRouteCanvas(
                routePreview: routePreview,
                progress: progress,
                petAvatarURL: petAvatarURL,
                petSex: petSex,
                routeBottomInset: routeBottomInset
            )

            PetWalkHistoryDetailPlaybackControls(
                progress: progress,
                elapsedText: elapsedText,
                isPlaying: isPlaying,
                onTogglePlayback: onTogglePlayback
            )
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.bottom, controlsBottomPadding)
        }
        .background(Color(red: 241 / 255, green: 245 / 255, blue: 249 / 255))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separator.color)
                .frame(height: 1)
        }
    }
}

// PetWalkHistoryDetailPlaybackControls 遛弯详情播放控制舱
// 核心职责：
// - 展示播放按钮、进度条和当前播放时间
// - 触发轨迹从起点重新播放
private struct PetWalkHistoryDetailPlaybackControls: View {
    let progress: Double
    let elapsedText: String
    let isPlaying: Bool
    let onTogglePlayback: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Button(action: onTogglePlayback) {
                Image(systemName: isPlaying ? "arrow.clockwise" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "重新播放轨迹" : "播放轨迹")

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255))

                    Capsule()
                        .fill(MHBTheme.ColorToken.primary.color)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 6)

            Text(elapsedText)
                .font(MHBTheme.Typography.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .accessibilityIdentifier("pet.walkHistory.detail.playbackControls")
    }
}

// PetWalkHistoryDetailFloatingSummary 遛弯详情底部悬浮摘要
// 核心职责：
// - 展示单次遛弯标题和时间
// - 展示时间、公里、时长三项核心信息
private struct PetWalkHistoryDetailFloatingSummary: View {
    let title: String
    let timeText: String
    let distanceText: String
    let durationText: String
    let bottomInset: CGFloat

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                Text(title)
                    .font(MHBTheme.Typography.headline.weight(.heavy))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
                    PetWalkHistoryDetailMetricItem(value: timeText, title: "时间")
                    PetWalkHistoryDetailMetricItem(value: distanceText, title: "公里")
                    PetWalkHistoryDetailMetricItem(value: durationText, title: "时长")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .frame(height: 116)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MHBTheme.ColorToken.cardSolid.color, in: .rect(cornerRadius: 32))
            .shadow(color: Color.black.opacity(0.16), radius: 24, x: 0, y: 10)
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s5 + bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier("pet.walkHistory.detail.floatingSummary")
    }
}

// PetWalkHistoryDetailMetricItem 遛弯详情摘要指标
// 核心职责：
// - 展示单个详情指标数值
// - 保持三列摘要数字宽度稳定
private struct PetWalkHistoryDetailMetricItem: View {
    let value: String
    let title: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(value)
                .font(MHBTheme.Typography.title.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(title)
                .font(MHBTheme.Typography.caption.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
