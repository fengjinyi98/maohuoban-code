import AVFoundation
import MaohuobanDiagnostics
import SwiftUI
import UIKit

// MHBMutedLoopingVideoView 静音循环视频 SwiftUI 包装
// 核心职责：
// - 使用 AVPlayerLayer 渲染无控制条的本地视频
// - 统一管理静音、循环和视图生命周期播放状态
struct MHBMutedLoopingVideoView: UIViewRepresentable {
    private let source: Source

    init(
        resourceName: String,
        fileExtension: String
    ) {
        self.source = .bundle(resourceName: resourceName, fileExtension: fileExtension)
    }

    init(url: URL) {
        self.source = .url(url)
    }

    func makeUIView(context: Context) -> LoopingVideoPlayerView {
        let view = LoopingVideoPlayerView()
        view.configure(source)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoPlayerView, context: Context) {
        uiView.configure(source)
    }

    static func dismantleUIView(_ uiView: LoopingVideoPlayerView, coordinator: ()) {
        uiView.stop()
    }

    enum Source: Equatable {
        case bundle(resourceName: String, fileExtension: String)
        case url(URL)
    }
}

// LoopingVideoPlayerView 本地循环视频承载视图
// 核心职责：
// - 持有 AVQueuePlayer 与 AVPlayerLooper
// - 在进入窗口时播放，离开窗口时暂停
final class LoopingVideoPlayerView: UIView {
    private var currentURL: URL?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var itemStatusObservation: NSKeyValueObservation?

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        playerLayer.videoGravity = .resizeAspectFill
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    func configure(resourceName: String, fileExtension: String) {
        guard let url = MHBLocalMediaResource.url(
            resourceName: resourceName,
            fileExtension: fileExtension
        ) else {
            stop()
            return
        }

        guard currentURL != url else {
            playIfVisible()
            return
        }

        currentURL = url

        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false

        let item = AVPlayerItem(url: url)
        observeItemStatus(item, source: "bundle", url: url)
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        player = queuePlayer
        looper = playerLooper
        playerLayer.player = queuePlayer

        playIfVisible()
    }

    func configure(_ source: MHBMutedLoopingVideoView.Source) {
        switch source {
        case .bundle(let resourceName, let fileExtension):
            configure(resourceName: resourceName, fileExtension: fileExtension)
        case .url(let url):
            configure(url: url)
        }
    }

    func configure(url: URL) {
        guard currentURL != url else {
            playIfVisible()
            return
        }

        currentURL = url
        recordVideoEvent(
            "pet.hero_video_player_configured",
            source: "remote",
            url: url
        )

        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false

        let item = AVPlayerItem(url: url)
        observeItemStatus(item, source: "remote", url: url)
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        player = queuePlayer
        looper = playerLooper
        playerLayer.player = queuePlayer

        playIfVisible()
    }

    func stop() {
        player?.pause()
        playerLayer.player = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        looper = nil
        player = nil
        currentURL = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            player?.pause()
        } else {
            playIfVisible()
        }
    }

    private func playIfVisible() {
        guard window != nil else {
            return
        }

        player?.play()
    }

    private func observeItemStatus(_ item: AVPlayerItem, source: String, url: URL) {
        itemStatusObservation?.invalidate()
        recordVideoEvent(
            "pet.hero_video_player_status",
            source: source,
            url: url,
            status: item.status.diagnosticsText,
            error: item.error
        )
        itemStatusObservation = item.observe(\.status, options: [.new]) { item, _ in
            let status = item.status.diagnosticsText
            let error = item.error
            Self.recordVideoEvent(
                "pet.hero_video_player_status",
                source: source,
                url: url,
                status: status,
                error: error
            )
        }
    }

    private func recordVideoEvent(
        _ eventName: String,
        source: String,
        url: URL,
        status: String? = nil,
        error: Error? = nil
    ) {
        Self.recordVideoEvent(
            eventName,
            source: source,
            url: url,
            status: status,
            error: error
        )
    }

    nonisolated private static func recordVideoEvent(
        _ eventName: String,
        source: String,
        url: URL,
        status: String? = nil,
        error: Error? = nil
    ) {
        let nsError = error as NSError?
        var properties: DiagnosticProperties = [
            "source": .string(source),
            "url": .string(url.absoluteString),
            "url_scheme": .string(url.scheme ?? ""),
            "file_extension": .string(url.pathExtension.lowercased()),
            "is_file_url": .bool(url.isFileURL)
        ]
        if let status {
            properties["status"] = .string(status)
        }
        if let nsError {
            properties["error_domain"] = .string(nsError.domain)
            properties["error_code"] = .int(nsError.code)
        }
        Task {
            await Diagnostics.track(eventName, properties: properties)
        }
    }
}

private extension AVPlayerItem.Status {
    nonisolated var diagnosticsText: String {
        switch self {
        case .unknown:
            "unknown"
        case .readyToPlay:
            "ready_to_play"
        case .failed:
            "failed"
        @unknown default:
            "unknown_default"
        }
    }
}
