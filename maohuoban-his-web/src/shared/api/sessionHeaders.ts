import { authHeaders } from "../auth/sessionStorage";

// sessionHeaders 当前操作上下文请求头
// 核心职责：
// - 返回真实后端 Bearer token 请求头
// - 让写入类操作复用统一鉴权来源
export function sessionHeaders(): Record<string, string> {
  return authHeaders();
}
