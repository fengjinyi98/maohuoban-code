import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { VisitEncounter } from "../../../shared/api/types";
import { readSession } from "../../../shared/auth/sessionStorage";
import { hasPermission } from "../../../shared/permissions/permissions";
import {
  getEncounter,
  listEncounters,
  saveEncounter,
  startEncounter,
} from "../data/encounterRepository";

// useEncounterViewModel 接诊病历状态
// 核心职责：
// - 加载接诊队列或单个就诊详情
// - 提供开始接诊和保存病历命令入口
export function useEncounterViewModel(encounterId?: string) {
  const queryClient = useQueryClient();
  const session = readSession();
  const canEdit = session
    ? hasPermission(session.role, "encounters.edit")
    : false;
  const listQuery = useQuery({
    queryKey: ["encounters"],
    queryFn: listEncounters,
    enabled: !encounterId,
  });
  const detailQuery = useQuery({
    queryKey: ["encounter", encounterId],
    queryFn: () => getEncounter(encounterId!),
    enabled: Boolean(encounterId),
  });

  const startMutation = useMutation({
    mutationFn: (id: string) => startEncounter(id),
    onSuccess: (encounter) => {
      queryClient.setQueryData(["encounter", encounter.id], encounter);
      queryClient.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });

  const saveMutation = useMutation({
    mutationFn: ({
      id,
      payload,
    }: {
      id: string;
      payload: Partial<VisitEncounter>;
    }) => saveEncounter(id, payload),
    onSuccess: (encounter) => {
      queryClient.setQueryData(["encounter", encounter.id], encounter);
      queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      queryClient.invalidateQueries({ queryKey: ["invoices"] });
    },
  });

  return { listQuery, detailQuery, startMutation, saveMutation, canEdit };
}
