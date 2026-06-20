import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { readSession } from "../../../shared/auth/sessionStorage";
import { hasPermission } from "../../../shared/permissions/permissions";
import {
  listPublications,
  updatePublication,
} from "../data/healthRecordRepository";
import type { PublicationAction } from "../domain/models";

// useHealthRecordsViewModel 健康档案发布状态
// 核心职责：
// - 加载待发布和发布历史
// - 提供发布、延迟发布和不发布命令入口
export function useHealthRecordsViewModel() {
  const queryClient = useQueryClient();
  const session = readSession();
  const canPublish = session
    ? hasPermission(session.role, "healthRecords.publish")
    : false;
  const query = useQuery({
    queryKey: ["publications"],
    queryFn: listPublications,
  });
  const updateMutation = useMutation({
    mutationFn: ({
      publicationId,
      action,
    }: {
      publicationId: string;
      action: PublicationAction;
    }) => updatePublication(publicationId, action),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["publications"] });
      queryClient.invalidateQueries({ queryKey: ["audit"] });
    },
  });

  return { ...query, canPublish, updateMutation };
}
