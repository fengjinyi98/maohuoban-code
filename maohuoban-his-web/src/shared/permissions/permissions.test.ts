import { describe, expect, it } from "vitest";
import { hasPermission } from "./permissions";

describe("hasPermission", () => {
  it("allows doctors to edit encounters and publish health records", () => {
    expect(hasPermission("doctor", "encounters.edit")).toBe(true);
    expect(hasPermission("doctor", "healthRecords.publish")).toBe(true);
  });

  it("prevents pharmacy role from editing medical records", () => {
    expect(hasPermission("pharmacy", "pharmacy.dispense")).toBe(true);
    expect(hasPermission("pharmacy", "encounters.edit")).toBe(false);
  });

  it("allows frontdesk charge but blocks pharmacy dispensing", () => {
    expect(hasPermission("frontdesk", "billing.charge")).toBe(true);
    expect(hasPermission("frontdesk", "pharmacy.dispense")).toBe(false);
  });
});
