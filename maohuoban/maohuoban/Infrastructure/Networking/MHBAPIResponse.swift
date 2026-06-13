import Foundation

// MHBAPIResponse 后端统一响应模型
// 核心职责：
// - 解析 Rust 后端统一 success/code/message/data 响应
// - 让业务层直接消费准确的后端 message
struct MHBAPIResponse<DataPayload: Decodable>: Decodable {
    let success: Bool
    let code: String
    let message: String
    let data: DataPayload?
}

// MHBEmptyResponse 空响应载荷
// 核心职责：
// - 承接后端 data 为空对象的成功响应
// - 保持泛型响应解析路径一致
struct MHBEmptyResponse: Decodable, Equatable {}
