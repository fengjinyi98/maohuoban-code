import SwiftUI

#if canImport(UIKit)
import UIKit

// MHBImagePreviewSourceRegistrationView 图片源注册桥接视图
// 核心职责：
// - 将 SwiftUI 图片 source 的可见 frame 注册到预览协调器
// - 只在布局事件边界上报 frame，禁止在 updateUIView 同步写 @Observable
struct MHBImagePreviewSourceRegistrationView: UIViewRepresentable {
    @Environment(\.mhbImagePreviewSourceRegistrar) private var registrar

    let sourceID: MHBImagePreviewSourceID
    let cornerRadius: CGFloat
    let asset: MHBImagePreviewAsset
    let observer: MHBImagePreviewSourceObserver

    func makeCoordinator() -> Coordinator {
        Coordinator(sourceID: sourceID)
    }

    func makeUIView(context: Context) -> MHBImagePreviewTrackingView {
        let view = MHBImagePreviewTrackingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.onLayout = { trackingView in
            context.coordinator.report(from: trackingView)
        }
        return view
    }

    func updateUIView(_ uiView: MHBImagePreviewTrackingView, context: Context) {
        context.coordinator.configure(
            registrar: registrar,
            observer: observer,
            trackingView: uiView,
            cornerRadius: cornerRadius,
            asset: asset
        )
        // 禁止在 updateUIView 里同步上报 frame（会在 SwiftUI update pass 中写 @Observable，
        // 叠加环境值重建引发雪崩）。frame 由 layoutSubviews/didMoveToWindow 事件驱动上报。
    }

    static func dismantleUIView(_ uiView: MHBImagePreviewTrackingView, coordinator: Coordinator) {
        coordinator.unregister()
    }

    @MainActor
    final class Coordinator {
        private let sourceID: MHBImagePreviewSourceID
        private let instanceID = UUID()
        private var registrar = MHBImagePreviewSourceRegistrar.noop
        private weak var trackingView: MHBImagePreviewTrackingView?
        private var observer: MHBImagePreviewSourceObserver?
        private var cornerRadius: CGFloat = 0
        private var asset: MHBImagePreviewAsset?
        private var didConnectObserver = false

        init(sourceID: MHBImagePreviewSourceID) {
            self.sourceID = sourceID
        }

        func configure(
            registrar: MHBImagePreviewSourceRegistrar,
            observer: MHBImagePreviewSourceObserver,
            trackingView: MHBImagePreviewTrackingView,
            cornerRadius: CGFloat,
            asset: MHBImagePreviewAsset
        ) {
            self.registrar = registrar
            self.observer = observer
            self.trackingView = trackingView
            self.cornerRadius = cornerRadius
            self.asset = asset
            // observer.connect 只连一次，后续 updateUIView 不重复注入闭包
            if !didConnectObserver {
                didConnectObserver = true
                observer.connect { [weak self] in
                    self?.captureCurrentSnapshot()
                }
            }
        }

        func report(from view: UIView) {
            guard let registration = makeRegistration(from: view) else { return }
            observer?.store(registration)
            registrar.register(registration)
        }

        func captureCurrentSnapshot() -> MHBImagePreviewSourceRegistration? {
            guard let trackingView,
                  let registration = makeRegistration(from: trackingView) else {
                return nil
            }
            observer?.store(registration)
            registrar.register(registration)
            return registration
        }

        func unregister() {
            observer?.disconnect(instanceID: instanceID)
            registrar.unregister(sourceID, instanceID)
        }

        private func makeRegistration(from view: UIView) -> MHBImagePreviewSourceRegistration? {
            guard view.window != nil,
                  let asset else {
                return nil
            }

            let frameInWindow = visibleFrameInWindow(for: view)
            guard !frameInWindow.isEmpty, !frameInWindow.isNull else {
                return nil
            }

            return MHBImagePreviewSourceRegistration(
                sourceID: sourceID,
                instanceID: instanceID,
                frameInWindow: frameInWindow,
                cornerRadius: cornerRadius,
                asset: asset
            )
        }

        private func visibleFrameInWindow(for view: UIView) -> CGRect {
            var visibleFrame = view.convert(view.bounds, to: nil)
            var ancestor = view.superview

            while let current = ancestor {
                if current is UIScrollView || current.clipsToBounds {
                    let ancestorFrame = current.convert(current.bounds, to: nil)
                    visibleFrame = visibleFrame.intersection(ancestorFrame)
                    if visibleFrame.isNull || visibleFrame.isEmpty {
                        break
                    }
                }
                ancestor = current.superview
            }

            return visibleFrame
        }
    }
}
#endif
