import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { readSession } from "../../../shared/auth/sessionStorage";
import { hasPermission } from "../../../shared/permissions/permissions";
import {
  dispenseEncounter,
  getPharmacyBoard,
} from "../data/pharmacyRepository";

// usePharmacyViewModel 药房状态
// 核心职责：
// - 加载待发药和库存预警
// - 提供确认发药和扣减库存命令入口
export function usePharmacyViewModel() {
  const queryClient = useQueryClient();
  const session = readSession();
  const canDispense = session
    ? hasPermission(session.role, "pharmacy.dispense")
    : false;
  const query = useQuery({ queryKey: ["pharmacy"], queryFn: getPharmacyBoard });
  const dispenseMutation = useMutation({
    mutationFn: dispenseEncounter,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["pharmacy"] });
      queryClient.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });

  return { ...query, canDispense, dispenseMutation };
}
