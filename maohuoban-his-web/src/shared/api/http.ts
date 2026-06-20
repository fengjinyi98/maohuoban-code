import type { ApiErrorPayload } from "./types";

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
// - 封装 mock API 请求和错误映射
// - 为后续 OpenAPI client 替换保留单一入口
export async function apiRequest<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const response = await fetch(path, {
    headers: {
      "content-type": "application/json",
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
