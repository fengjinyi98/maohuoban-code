import { expect, test } from "@playwright/test";

async function loginAsDoctor(page: import("@playwright/test").Page) {
  await page.goto("/login");
  await page.getByRole("button", { name: /周医生/ }).click();
  await page.getByRole("button", { name: "进入今日工作台" }).click();
  await expect(page.getByRole("heading", { name: "今日工作台" })).toBeVisible();
}

test("mock 登录、刷新恢复和退出登录", async ({ page }) => {
  await loginAsDoctor(page);
  await page.reload();
  await expect(page.getByRole("heading", { name: "今日工作台" })).toBeVisible();
  await page.getByRole("button", { name: "退出登录" }).click();
  await expect(page.getByRole("heading", { name: "员工登录" })).toBeVisible();
});

test("接诊到收费、发药、发布和审计闭环", async ({ page }) => {
  await loginAsDoctor(page);
  await page.getByRole("link", { name: /快速接诊/ }).click();
  await page.getByRole("button", { name: "开始接诊" }).click();
  await page.getByLabel("诊断").fill("慢性肾病复查，建议继续用药");
  await page.getByRole("button", { name: "保存病历并生成收费" }).click();

  await page.getByRole("button", { name: "退出登录" }).click();
  await page.getByRole("button", { name: /陈前台/ }).click();
  await page.getByRole("button", { name: "进入今日工作台" }).click();
  await page.getByRole("link", { name: "收费结算" }).click();
  await page.getByRole("button", { name: "微信收款" }).first().click();

  await page.getByRole("button", { name: "退出登录" }).click();
  await page.getByRole("button", { name: /王药房/ }).click();
  await page.getByRole("button", { name: "进入今日工作台" }).click();
  await page.getByRole("link", { name: "处方与发药" }).click();
  await page.getByRole("button", { name: "确认发药" }).first().click();

  await page.getByRole("button", { name: "退出登录" }).click();
  await page.getByRole("button", { name: /周医生/ }).click();
  await page.getByRole("button", { name: "进入今日工作台" }).click();
  await page.getByRole("link", { name: "健康档案发布", exact: true }).click();
  await expect(
    page.getByText("内部备注、成本、利润、方案模板未进入发布预览。").first(),
  ).toBeVisible();
  await page.getByRole("button", { name: "发布" }).first().click();
  await page.getByRole("button", { name: "退出登录" }).click();
  await page.getByRole("button", { name: /林院长/ }).click();
  await page.getByRole("button", { name: "进入今日工作台" }).click();
  await page.getByRole("link", { name: "授权审计" }).click();
  await page.getByRole("combobox").selectOption("publish");
  await expect(page.getByText("发布到宠物主 App").first()).toBeVisible();
});
