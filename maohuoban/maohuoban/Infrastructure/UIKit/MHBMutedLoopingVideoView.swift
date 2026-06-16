import AVFoundation
import SwiftUI
import UIKit

// MHBMutedLoopingVideoView 静音循环视频 SwiftUI 包装
// 核心职责：
// - 使用 AVPlayerLayer 渲染无控制条的本地视频
// - 统一管理静音、循环和视图生命周期播放状态
struct MHBMutedLoopingVideoView: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String

    func makeUIView(context: Context) -> LoopingVideoPlayerView {
        let view = LoopingVideoPlayerView()
        view.configure(resourceName: resourceName, fileExtension: fileExtension)
        return view
    }

    func updateUIView(_ uiView: LoopingVideoPlayerView, context: Context) {
        uiView.configure(resourceName: resourceName, fileExtension: fileExtension)
    }

    static func dismantleUIView(_ uiView: LoopingVideoPlayerView, coordinator: ()) {
        uiView.stop()
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
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        player = queuePlayer
        looper = playerLooper
        playerLayer.player = queuePlayer

        playIfVisible()
    }

    func stop() {
        player?.pause()
        playerLayer.player = nil
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
}
