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
                .ignoresSafeArea(.container, edges: .bottom)

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
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle("遛弯详情")
        .navigationBarTitleDisplayMode(.inline)
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

// PetWalkHistoryDetailRouteCanvas 遛弯详情路线画布
// 核心职责：
// - 归一化 mock 轨迹并绘制完整路线与已播放路线
// - 根据播放进度定位宠物 marker
private struct PetWalkHistoryDetailRouteCanvas: View {
    let routePreview: PetWalkHistoryRoutePreview
    let progress: Double
    let petAvatarURL: URL?
    let petSex: PetRecordPetSex
    let routeBottomInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let points = Self.routePoints(
                for: routePreview,
                in: proxy.size,
                bottomInset: routeBottomInset
            )
            let markerPoint = Self.point(at: progress, in: points)

            ZStack {
                PetWalkHistoryDetailMapGrid()

                Canvas { context, _ in
                    let fullPath = Self.path(from: points)
                    context.stroke(
                        fullPath,
                        with: .color(Color(red: 203 / 255, green: 213 / 255, blue: 225 / 255).opacity(0.45)),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )

                    let activePath = Self.path(from: Self.partialPoints(from: points, progress: progress))
                    context.stroke(
                        activePath,
                        with: .color(MHBTheme.ColorToken.primary.color),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )

                    if let startPoint = points.first {
                        Self.drawEndpoint(at: startPoint, color: .black, in: &context)
                    }
                }

                PetWalkHistoryDetailPetMarker(
                    url: petAvatarURL,
                    petSex: petSex
                )
                .position(markerPoint)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    private static func routePoints(
        for routePreview: PetWalkHistoryRoutePreview,
        in size: CGSize,
        bottomInset: CGFloat
    ) -> [CGPoint] {
        let normalizedPoints: [CGPoint]
        switch routePreview {
        case .arc:
            normalizedPoints = [
                CGPoint(x: 0.20, y: 0.82),
                CGPoint(x: 0.36, y: 0.66),
                CGPoint(x: 0.52, y: 0.78),
                CGPoint(x: 0.68, y: 0.58),
                CGPoint(x: 0.82, y: 0.36),
            ]
        case .loop:
            normalizedPoints = [
                CGPoint(x: 0.22, y: 0.74),
                CGPoint(x: 0.34, y: 0.42),
                CGPoint(x: 0.58, y: 0.34),
                CGPoint(x: 0.74, y: 0.58),
                CGPoint(x: 0.52, y: 0.76),
                CGPoint(x: 0.30, y: 0.66),
            ]
        case .curve:
            normalizedPoints = [
                CGPoint(x: 0.78, y: 0.24),
                CGPoint(x: 0.58, y: 0.38),
                CGPoint(x: 0.64, y: 0.58),
                CGPoint(x: 0.42, y: 0.70),
                CGPoint(x: 0.22, y: 0.56),
            ]
        }

        let topInset = MHBTheme.Spacing.s6
        let usableHeight = max(size.height - bottomInset - topInset, 1)

        return normalizedPoints.map { point in
            CGPoint(
                x: point.x * size.width,
                y: topInset + point.y * usableHeight
            )
        }
    }

    private static func path(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let firstPoint = points.first else { return path }

        path.move(to: firstPoint)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private static func partialPoints(
        from points: [CGPoint],
        progress: Double
    ) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        let clampedProgress = min(max(progress, 0), 1)
        let targetLength = totalLength(of: points) * clampedProgress
        var walkedLength: CGFloat = 0
        var result: [CGPoint] = [points[0]]

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let segmentLength = previous.distance(to: current)

            if walkedLength + segmentLength <= targetLength {
                result.append(current)
                walkedLength += segmentLength
            } else {
                let remaining = max(targetLength - walkedLength, 0)
                let segmentProgress = segmentLength == 0 ? 0 : remaining / segmentLength
                result.append(previous.interpolated(to: current, progress: segmentProgress))
                break
            }
        }

        return result
    }

    private static func point(
        at progress: Double,
        in points: [CGPoint]
    ) -> CGPoint {
        partialPoints(from: points, progress: progress).last ?? .zero
    }

    private static func totalLength(of points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }

        return points.indices.dropFirst().reduce(0) { length, index in
            length + points[index - 1].distance(to: points[index])
        }
    }

    private static func drawEndpoint(
        at point: CGPoint,
        color: Color,
        in context: inout GraphicsContext
    ) {
        let markerRect = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
        context.fill(Path(ellipseIn: markerRect), with: .color(color))
        context.stroke(Path(ellipseIn: markerRect), with: .color(.white), lineWidth: 2)
    }
}

// PetWalkHistoryDetailMapGrid 遛弯详情地图网格
// 核心职责：
// - 提供路线播放区域的地图纹理
// - 保持背景视觉与历史列表路线缩略图一致
private struct PetWalkHistoryDetailMapGrid: View {
    var body: some View {
        Canvas { context, size in
            let color = Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255).opacity(0.72)
            let spacing: CGFloat = 60

            var vertical = Path()
            var x: CGFloat = 0
            while x <= size.width {
                vertical.move(to: CGPoint(x: x, y: 0))
                vertical.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var horizontal = Path()
            var y: CGFloat = 0
            while y <= size.height {
                horizontal.move(to: CGPoint(x: 0, y: y))
                horizontal.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(vertical, with: .color(color), lineWidth: 1.5)
            context.stroke(horizontal, with: .color(color), lineWidth: 1.5)
        }
    }
}

// PetWalkHistoryDetailPetMarker 遛弯详情宠物轨迹标记
// 核心职责：
// - 展示沿轨迹移动的宠物头像
// - 用水滴形态强化当前位置语义
private struct PetWalkHistoryDetailPetMarker: View {
    let url: URL?
    let petSex: PetRecordPetSex

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black)
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(45))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.white, lineWidth: 2)
                        .rotationEffect(.degrees(45))
                }
                .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 6)

            MHBRemoteImage(url: url, contentMode: .fill) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(petSex.borderColor, lineWidth: 1.5)
            }
        }
        .frame(width: 52, height: 52)
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

private extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        hypot(point.x - x, point.y - y)
    }

    func interpolated(to point: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (point.x - x) * progress,
            y: y + (point.y - y) * progress
        )
    }
}
