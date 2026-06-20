import { useQuery } from "@tanstack/react-query";
import { getPatientDetail } from "../data/patientRepository";

// usePatientDetailViewModel 患者详情状态
// 核心职责：
// - 加载患者基础信息、历史就诊和收费记录
// - 支撑详情页风险展示
export function usePatientDetailViewModel(patientId: string) {
  return useQuery({
    queryKey: ["patient", patientId],
    queryFn: () => getPatientDetail(patientId),
  });
}
