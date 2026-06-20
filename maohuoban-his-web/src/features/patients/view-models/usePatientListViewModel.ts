import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { PetPatient } from "../../../shared/api/types";
import { createPatient, listPatients } from "../data/patientRepository";

// usePatientListViewModel 患者列表状态
// 核心职责：
// - 提供搜索和列表加载
// - 提供新建患者命令入口
export function usePatientListViewModel(keyword: string) {
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: ["patients", keyword],
    queryFn: () => listPatients(keyword),
  });
  const createMutation = useMutation({
    mutationFn: (
      patient: Omit<PetPatient, "id" | "medicalRecordNo" | "lastVisitAt">,
    ) => createPatient(patient),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["patients"] }),
  });

  return { ...query, createMutation };
}
