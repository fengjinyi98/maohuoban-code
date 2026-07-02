import SwiftUI
import MaohuobanDesignSystem

// PetWalkHistoryDetailRouteCanvas 遛弯详情路线画布
// 核心职责：
// - 归一化 mock 轨迹并绘制完整路线与已播放路线
// - 根据播放进度定位宠物 marker
struct PetWalkHistoryDetailRouteCanvas: View {
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

                PetWalkTeardropMarker(
                    avatarURL: petAvatarURL,
                    petSex: petSex
                )
                .position(x: markerPoint.x, y: markerPoint.y - 35)
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
