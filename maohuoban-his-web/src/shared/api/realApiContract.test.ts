import { describe, expect, it } from "vitest";

const sourceFiles = import.meta.glob<string>("../../**/*.ts*", {
  query: "?raw",
  import: "default",
  eager: true,
});

function read(relativePath: string) {
  const suffix = `/${relativePath.replace(/^src\//, "")}`;
  const key = Object.keys(sourceFiles).find((path) => path.endsWith(suffix));
  const source = key ? sourceFiles[key] : undefined;
  if (!source) {
    throw new Error(`source file not found: ${relativePath}`);
  }
  return source;
}

describe("Web HIS real API contract", () => {
  it("does not route feature repositories to mock API paths", () => {
    const repositoryFiles = [
      "src/features/auth/data/authRepository.ts",
      "src/features/dashboard/data/dashboardRepository.ts",
      "src/features/patients/data/patientRepository.ts",
      "src/features/encounters/data/encounterRepository.ts",
      "src/features/billing/data/billingRepository.ts",
      "src/features/pharmacy/data/pharmacyRepository.ts",
      "src/features/health-records/data/healthRecordRepository.ts",
      "src/features/audit/data/auditRepository.ts",
      "src/features/settings/data/settingsRepository.ts",
    ];

    for (const file of repositoryFiles) {
      expect(read(file), file).not.toContain("/api/mock");
    }
  });

  it("does not start MSW from the app entry", () => {
    const main = read("src/main.tsx");

    expect(main).not.toContain("VITE_ENABLE_MSW");
    expect(main).not.toContain("shared/mocks");
    expect(main).not.toContain("enableMocks");
  });
});
