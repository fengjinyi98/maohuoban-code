import Foundation

// MHBLocalMediaResource 本地媒体资源定位工具
// 核心职责：
// - 统一解析 Bundle 内置媒体文件 URL
// - 屏蔽资源目录结构差异对业务视图的影响
enum MHBLocalMediaResource {
    static func url(
        resourceName: String,
        fileExtension: String
    ) -> URL? {
        let subdirectories: [String?] = [
            nil,
            "Media",
            "Resources/Media"
        ]

        for subdirectory in subdirectories {
            if let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: fileExtension,
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        return nil
    }
}
