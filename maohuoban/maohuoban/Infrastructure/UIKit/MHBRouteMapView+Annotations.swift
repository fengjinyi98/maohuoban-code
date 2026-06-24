import MapKit
import UIKit

// MHBRouteMapOverlayTitle 路线叠加层标题键
// 核心职责：
// - 为轨迹 overlay 提供可区分的标题标识
// - 区分发光层与主干路线层
enum MHBRouteMapOverlayTitle {
    static let glow = "maohuoban.route.glow"
    static let route = "maohuoban.route.main"
}

// MHBRouteMapAnnotation 地图路线标记
// 核心职责：
// - 区分路线起点和当前宠物位置
// - 为宠物水滴标记携带头像和主题色
final class MHBRouteMapAnnotation: NSObject, MKAnnotation {
    enum Kind {
        case start
        case pet
    }

    dynamic var coordinate: CLLocationCoordinate2D
    let kind: Kind
    let avatarURL: URL?
    let markerColor: UIColor

    init(
        coordinate: CLLocationCoordinate2D,
        kind: Kind,
        avatarURL: URL?,
        markerColor: UIColor
    ) {
        self.coordinate = coordinate
        self.kind = kind
        self.avatarURL = avatarURL
        self.markerColor = markerColor
    }
}

// MHBRouteStartAnnotationView 路线起点标记
// 核心职责：
// - 在地图上展示黑色起点圆点
// - 与宠物当前位置标记形成路线起终点识别
final class MHBRouteStartAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "MHBRouteStartAnnotationView"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 18, height: 18)
        centerOffset = CGPoint(x: 0, y: -9)
        backgroundColor = .black
        layer.cornerRadius = 9
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 3
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
        collisionMode = .circle
        displayPriority = .required
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

// MHBPetRouteMarkerAnnotationView 宠物当前位置水滴标记
// 核心职责：
// - 使用倒置水滴承载宠物头像
// - 在地图轨迹末端表达当前宠物位置
final class MHBPetRouteMarkerAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "MHBPetRouteMarkerAnnotationView"
    static let userLocationReuseIdentifier = "MHBPetUserLocationAnnotationView"

    private let pulseView = UIView(frame: CGRect(x: 23, y: 55, width: 12, height: 12))
    private let teardropView = UIView(frame: CGRect(x: 2, y: 0, width: 54, height: 54))
    private let imageView = UIImageView(frame: CGRect(x: 4, y: 4, width: 46, height: 46))
    private var imageTask: Task<Void, Never>?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 58, height: 70)
        centerOffset = CGPoint(x: 0, y: -35)
        backgroundColor = .clear
        collisionMode = .circle
        displayPriority = .required

        pulseView.backgroundColor = .systemBlue
        pulseView.layer.cornerRadius = 6
        pulseView.alpha = 0.9
        addSubview(pulseView)

        teardropView.transform = CGAffineTransform(rotationAngle: -.pi / 4)
        teardropView.layer.cornerRadius = 27
        teardropView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner
        ]
        teardropView.layer.borderColor = UIColor.white.cgColor
        teardropView.layer.borderWidth = 2
        teardropView.layer.shadowColor = UIColor.black.cgColor
        teardropView.layer.shadowOpacity = 0.25
        teardropView.layer.shadowRadius = 16
        teardropView.layer.shadowOffset = CGSize(width: -4, height: 8)

        imageView.transform = CGAffineTransform(rotationAngle: .pi / 4)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 23
        imageView.clipsToBounds = true
        teardropView.addSubview(imageView)
        addSubview(teardropView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        imageView.image = Self.placeholderImage()
    }

    func configure(with annotation: MHBRouteMapAnnotation) {
        configure(
            annotation: annotation,
            avatarURL: annotation.avatarURL,
            markerColor: annotation.markerColor
        )
    }

    func configure(annotation: MKAnnotation, avatarURL: URL?, markerColor: UIColor) {
        self.annotation = annotation
        teardropView.backgroundColor = markerColor
        pulseView.backgroundColor = markerColor
        imageView.layer.borderColor = markerColor.cgColor
        imageView.layer.borderWidth = 2
        imageView.image = Self.placeholderImage()
        loadAvatar(from: avatarURL)
    }

    private func loadAvatar(from url: URL?) {
        imageTask?.cancel()
        guard let url else { return }

        imageTask = Task { [weak self] in
            do {
                let data = try await MHBRemoteMediaDataLoader.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                await MainActor.run {
                    self?.imageView.image = image
                }
            } catch {
                return
            }
        }
    }

    private static func placeholderImage() -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        return UIImage(systemName: "pawprint.fill", withConfiguration: configuration)
    }
}
