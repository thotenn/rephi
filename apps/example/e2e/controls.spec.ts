import type { Page } from "@playwright/test";
import { appUrl, expect, test } from "./support/fixtures";
import { probeControls, type ProbeOptions } from "./support/controls";

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

const goto = (page: Page, baseURL: string | undefined, path: string) => async () => {
  await page.goto(appUrl(baseURL, path));
};

test.describe("signed out", () => {
  for (const path of ["", "login", "register", "no-such-page"]) {
    test(`every control of /${path} works`, async ({ pageAs, baseURL }) => {
      const page = await pageAs(null);
      await expectNoDeadControls(page, { open: goto(page, baseURL, path) });
    });
  }
});

test.describe("administrator", () => {
  test("every control of the header and the home page works", async ({ asAdmin, baseURL }) => {
    const result = await expectNoDeadControls(asAdmin, { open: goto(asAdmin, baseURL, "home") });
    for (const entry of ["User Management", "Roles Management", "Permissions Management"]) {
      expect(result.exercised.some((line) => line.includes(`"${entry}": navigated`))).toBe(true);
    }
  });

  for (const path of ["pages/dashboard", "pages/profile", "admin/users", "admin/roles", "admin/permissions"]) {
    test(`every control of /${path} works`, async ({ asAdmin, baseURL }) => {
      await expectNoDeadControls(asAdmin, { open: goto(asAdmin, baseURL, path), scope: "main" });
    });
  }
});

test.describe("plain user", () => {
  test("every control of the header and the home page works", async ({ asPlainUser, baseURL }) => {
    const result = await expectNoDeadControls(asPlainUser, { open: goto(asPlainUser, baseURL, "home") });
    expect(result.exercised.join("\n")).not.toContain('"Admin"');
  });

  test("every control of the dashboard works", async ({ asPlainUser, baseURL }) => {
    await expectNoDeadControls(asPlainUser, { open: goto(asPlainUser, baseURL, "pages/dashboard"), scope: "main" });
  });

  test("the access-denied page leads back into the app", async ({ asPlainUser, baseURL }) => {
    const result = await expectNoDeadControls(asPlainUser, { open: goto(asPlainUser, baseURL, "admin/users") });
    expect(result.exercised).toEqual([expect.stringMatching(/^button "Go Back": navigated to .*\/home$/)]);
  });
});
