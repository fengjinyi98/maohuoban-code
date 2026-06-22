import CoreLocation
import SwiftUI
import MaohuobanDesignSystem

// PetWalkCompletionRoutePreview 遛弯结束路线预览
// 核心职责：
// - 将真实轨迹点归一化为卡片内路线缩略图
// - 在轨迹不足时提供稳定占位路线
struct PetWalkCompletionRoutePreview: View {
    let points: [CLLocationCoordinate2D]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PetWalkCompletionMapGrid()

                Canvas { context, size in
                    let route = Self.normalizedRoute(
                        from: points,
                        in: size
                    )
                    guard route.isEmpty == false else { return }

                    var path = Path()
                    path.move(to: route[0])
                    for point in route.dropFirst() {
                        path.addLine(to: point)
                    }

                    context.stroke(
                        path,
                        with: .color(MHBTheme.ColorToken.primary.color),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )

                    drawMarker(
                        at: route[0],
                        color: .black,
                        in: &context
                    )
                    drawMarker(
                        at: route[route.count - 1],
                        color: MHBTheme.ColorToken.primary.color,
                        in: &context
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(red: 226 / 255, green: 232 / 255, blue: 240 / 255))
        .accessibilityHidden(true)
    }

    private static func normalizedRoute(
        from coordinates: [CLLocationCoordinate2D],
        in size: CGSize
    ) -> [CGPoint] {
        guard coordinates.count >= 2 else {
            return fallbackRoute(in: size)
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLatitude = latitudes.min(),
              let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(),
              let maxLongitude = longitudes.max() else {
            return fallbackRoute(in: size)
        }

        let latitudeRange = max(maxLatitude - minLatitude, 0.000001)
        let longitudeRange = max(maxLongitude - minLongitude, 0.000001)
        let inset: CGFloat = 20
        let drawableWidth = max(size.width - inset * 2, 1)
        let drawableHeight = max(size.height - inset * 2, 1)

        return coordinates.map { coordinate in
            let xProgress = (coordinate.longitude - minLongitude) / longitudeRange
            let yProgress = (maxLatitude - coordinate.latitude) / latitudeRange
            return CGPoint(
                x: inset + CGFloat(xProgress) * drawableWidth,
                y: inset + CGFloat(yProgress) * drawableHeight
            )
        }
    }

    private static func fallbackRoute(in size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.24, y: size.height * 0.72),
            CGPoint(x: size.width * 0.44, y: size.height * 0.50),
            CGPoint(x: size.width * 0.64, y: size.height * 0.60),
            CGPoint(x: size.width * 0.76, y: size.height * 0.26)
        ]
    }

    private func drawMarker(
        at point: CGPoint,
        color: Color,
        in context: inout GraphicsContext
    ) {
        let markerRect = CGRect(
            x: point.x - 5,
            y: point.y - 5,
            width: 10,
            height: 10
        )
        context.fill(Path(ellipseIn: markerRect), with: .color(color))
        context.stroke(
            Path(ellipseIn: markerRect),
            with: .color(.white),
            lineWidth: 2
        )
    }
}

// PetWalkCompletionMapGrid 遛弯路线预览网格
// 核心职责：
// - 提供轻量地图占位纹理
// - 避免路线预览区域显得空白
private struct PetWalkCompletionMapGrid: View {
    var body: some View {
        Canvas { context, size in
            let color = Color(red: 203 / 255, green: 213 / 255, blue: 225 / 255).opacity(0.58)
            let spacing: CGFloat = 30

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
