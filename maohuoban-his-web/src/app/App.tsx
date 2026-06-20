import { RouterProvider } from "react-router-dom";
import { AppProviders } from "./providers/AppProviders";
import { router } from "./router";

// App 应用根组件
// 核心职责：
// - 挂载全局 Provider
// - 挂载前端路由
export function App() {
  return (
    <AppProviders>
      <RouterProvider router={router} />
    </AppProviders>
  );
}
