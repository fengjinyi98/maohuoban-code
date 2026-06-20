import { describe, expect, it } from "vitest";
import { ApiError } from "./http";

describe("ApiError", () => {
  it("keeps status and typed payload for UI error mapping", () => {
    const error = new ApiError(403, { code: "FORBIDDEN", message: "无权限" });

    expect(error.status).toBe(403);
    expect(error.payload.code).toBe("FORBIDDEN");
    expect(error.message).toBe("无权限");
  });
});
