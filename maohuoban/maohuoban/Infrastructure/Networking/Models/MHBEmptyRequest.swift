import Foundation

// MHBEmptyRequest 空请求载荷
// 核心职责：
// - 为需要 JSON body 的空 DELETE/POST 请求提供稳定 Encodable
// - 避免业务层散写空字典类型
struct MHBEmptyRequest: Encodable {}
