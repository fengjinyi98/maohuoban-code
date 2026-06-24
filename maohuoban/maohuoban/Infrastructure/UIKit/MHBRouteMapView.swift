import MapKit
import SwiftUI
import UIKit

// MHBRouteMapView 路线地图视图
// 核心职责：
// - 使用 MKMapView 展示真实地图底图和用户位置
// - 将轨迹点渲染为运动路线 overlay
struct MHBRouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let showsCurrentLocation: Bool
    let followsUser: Bool
    let petAvatarURL: URL?
    let petMarkerColor: UIColor
    let recenterRequestID: Int
    let onUserLocationUpdated: (CLLocation) -> Void

    private enum FocusMeters {
        static let initial: CLLocationDistance = 350
        static let recenter: CLLocationDistance = 300
    }

    private var shouldShowUserLocation: Bool {
        showsCurrentLocation || followsUser || recenterRequestID > 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        context.coordinator.petAvatarURL = petAvatarURL
        context.coordinator.petMarkerColor = petMarkerColor
        context.coordinator.onUserLocationUpdated = onUserLocationUpdated
        context.coordinator.isUserLocationRecenterPending = shouldShowUserLocation
        context.coordinator.pendingFocusMeters = FocusMeters.initial
        mapView.showsUserLocation = shouldShowUserLocation
        mapView.userTrackingMode = .none
        mapView.pointOfInterestFilter = .includingAll
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.backgroundColor = .systemGroupedBackground
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.petAvatarURL = petAvatarURL
        context.coordinator.petMarkerColor = petMarkerColor
        context.coordinator.onUserLocationUpdated = onUserLocationUpdated
        mapView.showsUserLocation = shouldShowUserLocation
        refreshRouteOverlay(in: mapView)
        refreshRouteAnnotations(in: mapView)

        if context.coordinator.shouldRecenter(
            recenterRequestID: recenterRequestID,
            coordinateCount: coordinates.count,
            followsUser: followsUser
        ) {
            focusUserLocation(in: mapView)
        }
        context.coordinator.lastRecenterRequestID = recenterRequestID
        context.coordinator.lastCoordinateCount = coordinates.count
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        mapView.delegate = nil
        mapView.showsUserLocation = false
        mapView.userTrackingMode = .none
        mapView.removeOverlays(mapView.overlays)
    }

    private func refreshRouteOverlay(in mapView: MKMapView) {
        let routeOverlays = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(routeOverlays)

        guard coordinates.count > 1 else { return }

        let glowPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        glowPolyline.title = MHBRouteMapOverlayTitle.glow
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        polyline.title = MHBRouteMapOverlayTitle.route
        mapView.addOverlays([glowPolyline, polyline])
    }

    private func refreshRouteAnnotations(in mapView: MKMapView) {
        let routeAnnotations = mapView.annotations.compactMap { $0 as? MHBRouteMapAnnotation }
        mapView.removeAnnotations(routeAnnotations)

        guard let latestCoordinate = coordinates.last else { return }

        if coordinates.count > 1, let startCoordinate = coordinates.first {
            mapView.addAnnotation(
                MHBRouteMapAnnotation(
                    coordinate: startCoordinate,
                    kind: .start,
                    avatarURL: nil,
                    markerColor: .black
                )
            )
        }

        if mapView.userLocation.location == nil {
            mapView.addAnnotation(
                MHBRouteMapAnnotation(
                    coordinate: latestCoordinate,
                    kind: .pet,
                    avatarURL: petAvatarURL,
                    markerColor: petMarkerColor
                )
            )
        }
    }

    private func focusUserLocation(in mapView: MKMapView) {
        guard shouldShowUserLocation else { return }

        if let userCoordinate = mapView.userLocation.location?.coordinate {
            setVisibleRegion(
                centeredAt: userCoordinate,
                meters: FocusMeters.recenter,
                in: mapView
            )
        } else {
            let coordinator = mapView.delegate as? Coordinator
            coordinator?.isUserLocationRecenterPending = true
            coordinator?.pendingFocusMeters = FocusMeters.recenter
        }
    }

    private func setVisibleRegion(
        centeredAt coordinate: CLLocationCoordinate2D,
        meters: CLLocationDistance,
        in mapView: MKMapView
    ) {
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: meters,
            longitudinalMeters: meters
        )
        mapView.setRegion(region, animated: true)
    }

    // Coordinator 地图代理
    // 核心职责：
    // - 为轨迹 overlay 提供统一渲染样式
    // - 保持 MapKit 委托逻辑隔离在 UIKit 边界内
    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastRecenterRequestID = 0
        var lastCoordinateCount = 0
        var isUserLocationRecenterPending = false
        var pendingFocusMeters = FocusMeters.initial
        var petAvatarURL: URL?
        var petMarkerColor = UIColor.black
        var onUserLocationUpdated: ((CLLocation) -> Void)?

        func shouldRecenter(
            recenterRequestID: Int,
            coordinateCount: Int,
            followsUser: Bool
        ) -> Bool {
            recenterRequestID != lastRecenterRequestID
        }

        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
        ) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            if polyline.title == MHBRouteMapOverlayTitle.glow {
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.24)
                renderer.lineWidth = 14
            } else {
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 6
            }
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MHBPetRouteMarkerAnnotationView.userLocationReuseIdentifier
                ) as? MHBPetRouteMarkerAnnotationView ?? MHBPetRouteMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: MHBPetRouteMarkerAnnotationView.userLocationReuseIdentifier
                )
                view.configure(
                    annotation: annotation,
                    avatarURL: petAvatarURL,
                    markerColor: petMarkerColor
                )
                return view
            }

            guard let routeAnnotation = annotation as? MHBRouteMapAnnotation else {
                return nil
            }

            switch routeAnnotation.kind {
            case .start:
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MHBRouteStartAnnotationView.reuseIdentifier
                ) as? MHBRouteStartAnnotationView ?? MHBRouteStartAnnotationView(
                    annotation: routeAnnotation,
                    reuseIdentifier: MHBRouteStartAnnotationView.reuseIdentifier
                )
                view.annotation = routeAnnotation
                return view
            case .pet:
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MHBPetRouteMarkerAnnotationView.reuseIdentifier
                ) as? MHBPetRouteMarkerAnnotationView ?? MHBPetRouteMarkerAnnotationView(
                    annotation: routeAnnotation,
                    reuseIdentifier: MHBPetRouteMarkerAnnotationView.reuseIdentifier
                )
                view.configure(with: routeAnnotation)
                return view
            }
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let location = userLocation.location else { return }

            let coordinate = location.coordinate
            onUserLocationUpdated?(location)

            guard isUserLocationRecenterPending else { return }
            isUserLocationRecenterPending = false
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: pendingFocusMeters,
                longitudinalMeters: pendingFocusMeters
            )
            mapView.setRegion(region, animated: true)
        }
    }
}
