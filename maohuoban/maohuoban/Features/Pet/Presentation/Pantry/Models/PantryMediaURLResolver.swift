import Foundation

// PantryMediaURLResolver 储物柜媒资地址解析器
// 核心职责：
// - 统一解析后端返回的储物柜媒资地址
// - 支持后端相对地址和外部绝对地址两种来源
enum PantryMediaURLResolver {
    static func resolve(_ urlString: String) -> URL? {
        MHBBackendEndpoint.resolve(urlString)
    }
}
