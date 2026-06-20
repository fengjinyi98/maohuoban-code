import { readSession } from "../auth/sessionStorage";

// sessionHeaders 当前操作上下文请求头
// 核心职责：
// - 将 mock session 传给 MSW 生成审计记录
// - 后续真实后端接入时替换为 token 头
export function sessionHeaders(): Record<string, string> {
  const session = readSession();
  return session
    ? {
        "x-mhb-session": encodeURIComponent(JSON.stringify(session)),
      }
    : {};
}
