import Foundation
import Photos

// MHBPHLivePhotoResourceLoader Live Photo 资源重建器
// 核心职责：
// - 从本地 still 与 paired video 文件重建 PHLivePhoto
// - 统一处理 PhotoKit 多次回调与单次 continuation 完成
enum MHBPHLivePhotoResourceLoader {
    static func request(resourceFileURLs: [URL]) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didResume = false

            func resumeOnce(returning livePhoto: PHLivePhoto?) {
                lock.lock()
                guard !didResume else {
                    lock.unlock()
                    return
                }
                didResume = true
                lock.unlock()

                continuation.resume(returning: livePhoto)
            }

            PHLivePhoto.request(
                withResourceFileURLs: resourceFileURLs,
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFill
            ) { livePhoto, info in
                if infoBoolValue(info, key: PHLivePhotoInfoCancelledKey) {
                    resumeOnce(returning: nil)
                    return
                }

                if info[PHLivePhotoInfoErrorKey] != nil {
                    resumeOnce(returning: nil)
                    return
                }

                guard !infoBoolValue(info, key: PHLivePhotoInfoIsDegradedKey) else {
                    return
                }

                resumeOnce(returning: livePhoto)
            }
        }
    }

    private static func infoBoolValue(
        _ info: [AnyHashable: Any],
        key: String
    ) -> Bool {
        if let value = info[key] as? Bool {
            return value
        }

        if let value = info[key] as? NSNumber {
            return value.boolValue
        }

        return false
    }
}
