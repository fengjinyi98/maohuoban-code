import type { AuthSession } from "../api/types";

const SESSION_KEY = "maohuoban.webHis.session";

// readSession 读取 mock 登录态
// 核心职责：
// - 从浏览器本地存储恢复 session
// - 避免解析失败影响首屏
export function readSession(): AuthSession | null {
  const raw = window.localStorage.getItem(SESSION_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as AuthSession;
  } catch {
    window.localStorage.removeItem(SESSION_KEY);
    return null;
  }
}

// writeSession 写入 mock 登录态
// 核心职责：
// - 持久化当前医院上下文
// - 支撑刷新恢复
export function writeSession(session: AuthSession) {
  window.localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

// clearSession 清除 mock 登录态
// 核心职责：
// - 退出登录时清空本地上下文
// - 让路由回到登录页
export function clearSession() {
  window.localStorage.removeItem(SESSION_KEY);
}
