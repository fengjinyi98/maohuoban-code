import { useQuery } from "@tanstack/react-query";
import { getSettingsBoard } from "../data/settingsRepository";

// useSettingsViewModel 设置页状态
// 核心职责：
// - 加载员工、角色、院区和药品配置
// - 支撑管理员权限展示
export function useSettingsViewModel() {
  return useQuery({ queryKey: ["settings"], queryFn: getSettingsBoard });
}
