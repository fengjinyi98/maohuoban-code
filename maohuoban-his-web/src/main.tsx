import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app/App";
import "./globals.css";

// enableMocks 用于开发和 E2E 阶段启动浏览器内 MSW
// 核心职责：
// - 在 mock 开关开启时注册 Service Worker
// - 保持应用入口只依赖统一 API client
async function enableMocks() {
  if (import.meta.env.PROD || import.meta.env.VITE_ENABLE_MSW === "false") {
    return;
  }

  const { worker } = await import("./shared/mocks/browser");
  await worker.start({ onUnhandledRequest: "bypass" });
}

await enableMocks();

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
