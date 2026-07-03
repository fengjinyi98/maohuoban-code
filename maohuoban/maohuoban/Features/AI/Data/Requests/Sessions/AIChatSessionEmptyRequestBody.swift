import Foundation

// AIChatSessionEmptyRequestBody AI 会话空请求体
// 核心职责：
// - 复用 JSON DELETE 发送路径
// - 承接只依赖路径和授权头的会话删除命令
struct AIChatSessionEmptyRequestBody: Encodable {}
