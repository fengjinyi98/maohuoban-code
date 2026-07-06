import type { ApiErrorPayload } from "./types";
import { authHeaders } from "../auth/sessionStorage";

export class ApiError extends Error {
  public readonly status: number;
  public readonly payload: ApiErrorPayload;

  constructor(status: number, payload: ApiErrorPayload) {
    super(payload.message);
    this.status = status;
    this.payload = payload;
  }
}

// apiRequest 统一 HTTP client
// 核心职责：
// - 封装真实后端 API 请求和错误映射
// - 为 Web HIS 提供统一 Bearer token 注入入口
export async function apiRequest<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(apiURL(path), {
    headers: {
      "content-type": "application/json",
      ...authHeaders(),
      ...init?.headers,
    },
    ...init,
  });

  if (!response.ok) {
    const payload = (await response.json()) as ApiErrorPayload;
    throw new ApiError(response.status, payload);
  }

  return (await response.json()) as T;
}

// toJsonBody 请求体序列化
// 核心职责：
// - 统一 POST/PATCH JSON 负载
// - 避免页面层拼接 RequestInit
export function toJsonBody(body: unknown): RequestInit {
  return {
    method: "POST",
    body: JSON.stringify(body),
  };
}

// apiURL 解析后端 API 地址
// 核心职责：
// - 本地开发默认使用 Vite 同源代理访问 Rust 后端
// - 支持 VITE_API_BASE_URL 覆盖部署地址
function apiURL(path: string) {
  const baseURL = import.meta.env.VITE_API_BASE_URL ?? window.location.origin;
  return new URL(path, baseURL).toString();
}
