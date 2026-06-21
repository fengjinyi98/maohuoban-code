import AVFoundation
import UIKit

// MHBResponsiveCameraViewController 响应式相机控制器
// 核心职责：
// - 配置 AVFoundation 预览和单张照片采集
// - 使用 Deferred Start 和 Responsive Capture 优化启动与拍照响应
final class MHBResponsiveCameraViewController: UIViewController {
    private let onComplete: (UIImage) -> Void
    private let onCancel: () -> Void
    private let onFailure: (String) -> Void

    nonisolated(unsafe) private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.maohuoban.camera.session", qos: .userInitiated)
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    private let previewView = MHBResponsiveCameraPreviewView()
    private let shutterButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    private var photoCaptureDelegate: MHBResponsiveCameraPhotoCaptureDelegate?
    nonisolated(unsafe) private var isSessionConfigured = false

    init(
        onComplete: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void,
        onFailure: @escaping (String) -> Void
    ) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureControls()
        prepareCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewView.frame = view.bounds
        updatePreviewOrientation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func configureView() {
        view.backgroundColor = .black
        previewView.videoPreviewLayer.session = captureSession
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)

        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureControls() {
        configureCancelButton()
        configureShutterButton()
        configureActivityIndicator()
    }

    private func configureCancelButton() {
        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        cancelButton.layer.cornerRadius = 22
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelButton.widthAnchor.constraint(equalToConstant: 44),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configureShutterButton() {
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 36
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.54).cgColor
        shutterButton.layer.borderWidth = 5
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addTarget(self, action: #selector(shutterButtonTapped), for: .touchUpInside)
        view.addSubview(shutterButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            shutterButton.widthAnchor.constraint(equalToConstant: 72),
            shutterButton.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    private func configureActivityIndicator() {
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func prepareCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    if isGranted {
                        self.configureSession()
                    } else {
                        self.failAndDismiss("请允许毛伙伴访问相机")
                    }
                }
            }
        case .denied, .restricted:
            failAndDismiss("请在系统设置中允许毛伙伴访问相机")
        @unknown default:
            failAndDismiss("当前相机权限状态不可用")
        }
    }

    private func configureSession() {
        activityIndicator.startAnimating()
        shutterButton.isEnabled = false

        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            do {
                try self.configureSessionOnQueue()
                self.captureSession.startRunning()

                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.shutterButton.isEnabled = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.failAndDismiss("相机启动失败，请重试")
                }
            }
        }
    }

    nonisolated private func configureSessionOnQueue() throws {
        guard !isSessionConfigured else {
            return
        }

        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }

        captureSession.sessionPreset = .photo
        captureSession.automaticallyRunsDeferredStart = true

        let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) ?? AVCaptureDevice.default(for: .video)

        guard let device else {
            throw MHBResponsiveCameraError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard captureSession.canAddInput(input) else {
            throw MHBResponsiveCameraError.configurationFailed
        }
        captureSession.addInput(input)

        guard captureSession.canAddOutput(photoOutput) else {
            throw MHBResponsiveCameraError.configurationFailed
        }
        captureSession.addOutput(photoOutput)

        photoOutput.isDeferredStartEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .balanced
        if photoOutput.isResponsiveCaptureSupported {
            photoOutput.isResponsiveCaptureEnabled = true
        }
        if photoOutput.isFastCapturePrioritizationSupported {
            photoOutput.isFastCapturePrioritizationEnabled = true
        }

        isSessionConfigured = true
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self,
                  self.captureSession.isRunning
            else {
                return
            }
            self.captureSession.stopRunning()
        }
    }

    private func updatePreviewOrientation() {
        guard let connection = previewView.videoPreviewLayer.connection,
              connection.isVideoRotationAngleSupported(90)
        else {
            return
        }
        connection.videoRotationAngle = 90
    }

    @objc
    private func cancelButtonTapped() {
        onCancel()
    }

    @objc
    private func shutterButtonTapped() {
        shutterButton.isEnabled = false

        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced

        let delegate = MHBResponsiveCameraPhotoCaptureDelegate(
            onComplete: { [weak self] image in
                DispatchQueue.main.async {
                    self?.onComplete(image)
                }
            },
            onFailure: { [weak self] message in
                DispatchQueue.main.async {
                    self?.failAndDismiss(message)
                }
            },
            onFinish: { [weak self] in
                DispatchQueue.main.async {
                    self?.photoCaptureDelegate = nil
                    self?.shutterButton.isEnabled = true
                }
            }
        )
        photoCaptureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func failAndDismiss(_ message: String) {
        onFailure(message)
    }
}
