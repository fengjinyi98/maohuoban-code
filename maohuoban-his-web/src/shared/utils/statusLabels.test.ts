import { describe, expect, it } from "vitest";
import { formatCurrency, invoiceTotal } from "./statusLabels";

describe("billing helpers", () => {
  it("calculates invoice total from quantity and unit price", () => {
    expect(
      invoiceTotal([
        { quantity: 2, unitPrice: 12.5 },
        { quantity: 1, unitPrice: 80 },
      ]),
    ).toBe(105);
  });

  it("formats RMB currency", () => {
    expect(formatCurrency(105)).toBe("¥105.00");
  });
});
