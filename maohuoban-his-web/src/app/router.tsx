import { createBrowserRouter, Navigate } from "react-router-dom";
import { AppLayout } from "./layouts/AppLayout";
import { AuthGuard } from "../shared/auth/AuthGuard";
import { PermissionGuard } from "../shared/permissions/PermissionGuard";
import { ForbiddenPage } from "../shared/components/ForbiddenPage";
import { LoginPage } from "../features/auth/presentation/LoginPage";
import { ContextSelectPage } from "../features/auth/presentation/ContextSelectPage";
import { DashboardPage } from "../features/dashboard/presentation/DashboardPage";
import { PatientsPage } from "../features/patients/presentation/PatientsPage";
import { PatientDetailPage } from "../features/patients/presentation/PatientDetailPage";
import { NewPatientPage } from "../features/patients/presentation/NewPatientPage";
import { EncounterPage } from "../features/encounters/presentation/EncounterPage";
import { BillingPage } from "../features/billing/presentation/BillingPage";
import { PharmacyPage } from "../features/pharmacy/presentation/PharmacyPage";
import { HealthRecordsPage } from "../features/health-records/presentation/HealthRecordsPage";
import { AuditPage } from "../features/audit/presentation/AuditPage";
import { SettingsPage } from "../features/settings/presentation/SettingsPage";

// router Web HIS 路由配置
// 核心职责：
// - 建立登录态和权限保护
// - 承载医院端一级模块
export const router = createBrowserRouter([
  {
    path: "/login",
    element: <LoginPage />,
  },
  {
    path: "/select-context",
    element: (
      <AuthGuard>
        <ContextSelectPage />
      </AuthGuard>
    ),
  },
  {
    path: "/403",
    element: <ForbiddenPage />,
  },
  {
    path: "/",
    element: (
      <AuthGuard requireContext>
        <AppLayout />
      </AuthGuard>
    ),
    children: [
      { index: true, element: <Navigate to="/dashboard" replace /> },
      {
        path: "dashboard",
        element: (
          <PermissionGuard permission="dashboard.view">
            <DashboardPage />
          </PermissionGuard>
        ),
      },
      {
        path: "patients",
        element: (
          <PermissionGuard permission="patients.view">
            <PatientsPage />
          </PermissionGuard>
        ),
      },
      {
        path: "patients/new",
        element: (
          <PermissionGuard permission="patients.create">
            <NewPatientPage />
          </PermissionGuard>
        ),
      },
      {
        path: "patients/:patientId",
        element: (
          <PermissionGuard permission="patients.view">
            <PatientDetailPage />
          </PermissionGuard>
        ),
      },
      {
        path: "encounters/:encounterId?",
        element: (
          <PermissionGuard permission="encounters.view">
            <EncounterPage />
          </PermissionGuard>
        ),
      },
      {
        path: "billing",
        element: (
          <PermissionGuard permission="billing.view">
            <BillingPage />
          </PermissionGuard>
        ),
      },
      {
        path: "pharmacy",
        element: (
          <PermissionGuard permission="pharmacy.view">
            <PharmacyPage />
          </PermissionGuard>
        ),
      },
      {
        path: "health-records",
        element: (
          <PermissionGuard permission="healthRecords.view">
            <HealthRecordsPage />
          </PermissionGuard>
        ),
      },
      {
        path: "audit",
        element: (
          <PermissionGuard permission="audit.view">
            <AuditPage />
          </PermissionGuard>
        ),
      },
      {
        path: "settings",
        element: (
          <PermissionGuard permission="settings.view">
            <SettingsPage />
          </PermissionGuard>
        ),
      },
    ],
  },
]);
