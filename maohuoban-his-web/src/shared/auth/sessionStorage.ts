import type { AuthSession } from "../api/types";

const SESSION_KEY = "maohuoban.webHis.session";
const TOKEN_KEY = "maohuoban.webHis.accessToken";

// readSession 读取真实登录态
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

// writeSession 写入真实登录态
// 核心职责：
// - 持久化当前医院上下文
// - 支撑刷新恢复
export function writeSession(session: AuthSession) {
  if (session.accessToken) {
    window.localStorage.setItem(TOKEN_KEY, session.accessToken);
  }
  window.localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

// authHeaders 返回真实后端鉴权头
// 核心职责：
// - 从本地登录态读取 access token
// - 为统一 API client 注入 Bearer token
export function authHeaders(): Record<string, string> {
  const token = window.localStorage.getItem(TOKEN_KEY);
  return token ? { Authorization: `Bearer ${token}` } : {};
}

// clearSession 清除真实登录态
// 核心职责：
// - 退出登录时清空本地上下文
// - 让路由回到登录页
export function clearSession() {
  window.localStorage.removeItem(SESSION_KEY);
  window.localStorage.removeItem(TOKEN_KEY);
}
