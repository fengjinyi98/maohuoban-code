import { useState } from "react";
import { useNavigate } from "react-router-dom";
import type { PetPatient } from "../../../shared/api/types";
import { HisPageShell } from "../../../shared/components/HisPageShell";
import { usePatientListViewModel } from "../view-models/usePatientListViewModel";

// NewPatientPage 新建患者页
// 核心职责：
// - 采集宠物和主人基础信息
// - 通过真实后端患者写入接口完成建档
export function NewPatientPage() {
  const navigate = useNavigate();
  const vm = usePatientListViewModel("");
  const [form, setForm] = useState<
    Omit<PetPatient, "id" | "medicalRecordNo" | "lastVisitAt">
  >({
    name: "",
    species: "猫" as const,
    breed: "",
    ageText: "",
    sex: "",
    weightKg: 0,
    ownerId: "",
    ownerName: "",
    ownerPhone: "",
    allergies: [] as string[],
    chronicDiseases: [] as string[],
    currentMedications: [] as string[],
    notes: "",
  });

  async function submit() {
    const patient = await vm.createMutation.mutateAsync(form);
    navigate(`/patients/${patient.id}`);
  }

  return (
    <HisPageShell
      title="新建患者"
      description="前台、医生和助理可创建院内宠物患者档案。"
    >
      <section className="mhb-card mhb-grid">
        <div className="mhb-grid mhb-grid-3">
          <label className="mhb-field">
            <span>宠物名</span>
            <input
              className="mhb-input"
              value={form.name}
              onChange={(event) =>
                setForm({ ...form, name: event.target.value })
              }
            />
          </label>
          <label className="mhb-field">
            <span>物种</span>
            <select
              className="mhb-input"
              value={form.species}
              onChange={(event) =>
                setForm({ ...form, species: event.target.value as "猫" | "狗" })
              }
            >
              <option>猫</option>
              <option>狗</option>
            </select>
          </label>
          <label className="mhb-field">
            <span>品种</span>
            <input
              className="mhb-input"
              value={form.breed}
              onChange={(event) =>
                setForm({ ...form, breed: event.target.value })
              }
            />
          </label>
          <label className="mhb-field">
            <span>年龄</span>
            <input
              className="mhb-input"
              value={form.ageText}
              onChange={(event) =>
                setForm({ ...form, ageText: event.target.value })
              }
            />
          </label>
          <label className="mhb-field">
            <span>性别</span>
            <input
              className="mhb-input"
              value={form.sex}
              onChange={(event) =>
                setForm({ ...form, sex: event.target.value })
              }
            />
          </label>
          <label className="mhb-field">
            <span>体重 kg</span>
            <input
              className="mhb-input"
              type="number"
              value={form.weightKg}
              onChange={(event) =>
                setForm({ ...form, weightKg: Number(event.target.value) })
              }
            />
          </label>
          <label className="mhb-field">
            <span>主人姓名</span>
            <input
              className="mhb-input"
              value={form.ownerName}
              onChange={(event) =>
                setForm({ ...form, ownerName: event.target.value })
              }
            />
          </label>
          <label className="mhb-field">
            <span>主人手机号</span>
            <input
              className="mhb-input"
              value={form.ownerPhone}
              onChange={(event) =>
                setForm({ ...form, ownerPhone: event.target.value })
              }
            />
          </label>
          <label className="mhb-field">
            <span>备注</span>
            <input
              className="mhb-input"
              value={form.notes}
              onChange={(event) =>
                setForm({ ...form, notes: event.target.value })
              }
            />
          </label>
        </div>
        <button
          className="mhb-button primary"
          type="button"
          onClick={() => void submit()}
          disabled={vm.createMutation.isPending}
        >
          保存患者
        </button>
      </section>
    </HisPageShell>
  );
}
