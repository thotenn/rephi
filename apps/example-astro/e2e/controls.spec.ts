import type { Page } from "@playwright/test";
import { probeControls, type ProbeOptions } from "./support/controls";
import { expect, open, test } from "./support/fixtures";

const SKIP = /^(Logout|Assign|Remove)$/;

async function expectNoDeadControls(page: Page, options: ProbeOptions) {
  const result = await probeControls(page, { skip: SKIP, ...options });
  test.info().annotations.push(
    ...result.exercised.map((description) => ({ type: "clicked", description })),
    ...result.skipped.map((description) => ({ type: "skipped", description }))
  );
  expect(result.dead, "controls that did nothing").toEqual([]);
  expect(result.exercised.length, "controls clicked").toBeGreaterThan(0);
  return result;
}

test.describe("signed out", () => {
  for (const path of ["", "login/", "register/", "no-such-page/"]) {
    test(`every control of /${path} works`, async ({ pageAs }) => {
      const page = await pageAs(null);
      await expectNoDeadControls(page, { open: () => open(page, path) });
    });
  }
});

test.describe("administrator", () => {
  test("every control of the header and the home page works", async ({ asAdmin }) => {
    const result = await expectNoDeadControls(asAdmin, { open: () => open(asAdmin, "home/") });
    for (const entry of ["User Management", "Roles Management", "Permissions Management"]) {
      expect(result.exercised.some((line) => line.includes(`"${entry}": navigated`))).toBe(true);
    }
  });

  for (const path of ["pages/dashboard/", "pages/profile/", "admin/users/", "admin/roles/", "admin/permissions/"]) {
    test(`every control of /${path} works`, async ({ asAdmin }) => {
      await expectNoDeadControls(asAdmin, { open: () => open(asAdmin, path), scope: "main" });
    });
  }
});

test.describe("plain user", () => {
  test("every control of the header and the home page works", async ({ asPlainUser }) => {
    const result = await expectNoDeadControls(asPlainUser, { open: () => open(asPlainUser, "home/") });
    expect(result.exercised.join("\n")).not.toContain('"Admin"');
  });

  test("every control of the dashboard works", async ({ asPlainUser }) => {
    await expectNoDeadControls(asPlainUser, { open: () => open(asPlainUser, "pages/dashboard/"), scope: "main" });
  });

  test("the access-denied page leads back into the app", async ({ asPlainUser }) => {
    const result = await expectNoDeadControls(asPlainUser, { open: () => open(asPlainUser, "admin/users/") });
    expect(result.exercised).toContainEqual(expect.stringMatching(/^button "Go Back": navigated to .*\/home\/$/));
  });

  test('"Go Back" returns to the previous page of the app', async ({ asPlainUser }) => {
    await open(asPlainUser, "pages/dashboard/");
    await asPlainUser.evaluate(() => {
      const link = document.createElement("a");
      link.href = "../../admin/users/";
      link.id = "e2e-link";
      link.textContent = "users";
      document.body.append(link);
    });
    await asPlainUser.locator("#e2e-link").click();
    await expect(asPlainUser.getByRole("heading", { name: "Access Denied" })).toBeVisible();
    await asPlainUser.getByRole("button", { name: "Go Back" }).click();
    await expect(asPlainUser).toHaveURL(/\/pages\/dashboard\/$/);
  });
});
