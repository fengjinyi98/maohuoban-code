import Foundation

// DiagnosticsCoding 诊断 JSON 编解码配置
// 核心职责：
// - 统一 Swift SDK 事件落盘与远端镜像的时间格式
// - 避免不同输出通道生成不兼容的 JSON 表达
extension JSONEncoder {
    static var maohuobanDiagnostics: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var maohuobanDiagnostics: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
