import type { Locator, Page } from "@playwright/test";
import { ADMIN, api, cleanup, TEST_PASSWORD, unique, type Session } from "./support/api";
import { appUrl, expect, test } from "./support/fixtures";

async function storedSession(page: Page): Promise<Session> {
  const raw = await page.evaluate(() => localStorage.getItem("auth-storage"));
  const { state } = JSON.parse(raw ?? "{}") as { state: Session };
  return state;
}

function itemButton(list: Locator, text: string, button: string): Locator {
  return list
    .locator("div")
    .filter({ hasText: text })
    .filter({ has: list.page().getByRole("button", { name: button }) })
    .last()
    .getByRole("button", { name: button });
}

async function showRow(page: Page, testId: string) {
  const row = page.getByTestId(testId);
  const next = page.getByRole("button", { name: "Next" });
  await expect(page.getByRole("table").first()).toBeVisible();
  while (!(await row.isVisible()) && (await next.isVisible()) && (await next.isEnabled())) {
    await next.click();
    await page.waitForLoadState("networkidle");
  }
  await expect(row).toBeVisible();
  return row;
}

test.describe("sessions", () => {
  test("the administrator signs in through the login form", async ({ pageAs, baseURL }) => {
    const page = await pageAs(null);
    await page.goto(appUrl(baseURL, ""));
    await page.getByRole("link", { name: "Sign In" }).click();

    await page.getByPlaceholder("Email address").fill(ADMIN.email);
    await page.getByPlaceholder("Password").fill(ADMIN.password);
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page).toHaveURL(appUrl(baseURL, "home"));
    await expect(page.getByRole("button", { name: "Admin" })).toBeVisible();
  });

  test("a visitor registers and lands on the home page", async ({ pageAs, adminSession, baseURL }) => {
    const page = await pageAs(null);
    const email = `${unique("e2e-signup")}@example.com`;
    await page.goto(appUrl(baseURL, "register"));
    await page.getByLabel("Email address").fill(email);
    await page.getByLabel("Password", { exact: true }).fill(TEST_PASSWORD);
    await page.getByLabel("Confirm Password").fill(TEST_PASSWORD);
    await page.getByRole("button", { name: "Create account" }).click();

    await expect(page).toHaveURL(appUrl(baseURL, "home"));
    const session = await storedSession(page);
    await cleanup(() => api.deleteUser(adminSession.token, session.user.id));
  });

  test("Logout ends the session", async ({ pageAs, adminSession, baseURL }) => {
    const session = await api.registerUnique("e2e-logout");
    try {
      const page = await pageAs(session);
      await page.goto(appUrl(baseURL, "home"));
      await page.getByRole("button", { name: "Logout" }).click();

      await expect(page).toHaveURL(appUrl(baseURL, "login"));
      await expect(page.getByText("You have been signed out.")).toBeVisible();
      await page.goto(appUrl(baseURL, "pages/profile"));
      await expect(page).toHaveURL(appUrl(baseURL, "login"));
    } finally {
      await cleanup(() => api.deleteUser(adminSession.token, session.user.id));
    }
  });

  test("Change password keeps the user signed in with the new password", async ({ pageAs, adminSession, baseURL }) => {
    const session = await api.registerUnique("e2e-password");
    const newPassword = "e2e-password-2";
    try {
      const page = await pageAs(session);
      await page.goto(appUrl(baseURL, "pages/profile"));
      await page.getByLabel("Current password").fill(TEST_PASSWORD);
      await page.getByLabel("New password", { exact: true }).fill(newPassword);
      await page.getByLabel("Confirm new password").fill(newPassword);
      await page.getByRole("button", { name: "Change password" }).click();

      await expect(page.getByText("Password changed.")).toBeVisible();
      await page.reload();
      await expect(page).toHaveURL(appUrl(baseURL, "pages/profile"));
      await api.login(session.user.email, newPassword);
    } finally {
      await cleanup(() => api.deleteUser(adminSession.token, session.user.id));
    }
  });
});

test.describe("administration on throwaway data", () => {
  test("a user's roles are assigned and removed, its email edited, then the user deleted", async ({
    asAdmin,
    adminSession,
    baseURL,
  }) => {
    const { user } = await api.registerUnique("e2e-managed");
    const newEmail = `${unique("e2e-renamed")}@example.com`;
    try {
      await asAdmin.goto(appUrl(baseURL, "admin/users"));
      let row = await showRow(asAdmin, `user-row-${user.email}`);

      await row.getByRole("button", { name: "Manage Roles" }).click();
      const dialog = asAdmin.getByRole("dialog");
      const current = dialog.getByTestId("current-roles");
      const available = dialog.getByTestId("available-roles");
      await itemButton(available, "Manager", "Assign").click();
      await expect(current).toContainText("Manager");
      expect((await api.userRoles(adminSession.token, user.id)).map((role) => role.slug)).toContain("manager");

      await itemButton(current, "Manager", "Remove").click();
      await expect(current).not.toContainText("Manager");
      expect((await api.userRoles(adminSession.token, user.id)).map((role) => role.slug)).not.toContain("manager");
      await dialog.getByRole("button", { name: "Close modal" }).click();
      await expect(dialog).toBeHidden();

      await row.getByRole("button", { name: "Edit" }).click();
      await asAdmin.getByRole("dialog").getByLabel("Email").fill(newEmail);
      await asAdmin.getByRole("dialog").getByRole("button", { name: "Save" }).click();
      await expect(asAdmin.getByText(`Email changed to ${newEmail}`)).toBeVisible();
      row = await showRow(asAdmin, `user-row-${newEmail}`);

      asAdmin.once("dialog", (confirm) => void confirm.accept());
      await row.getByRole("button", { name: "Delete" }).click();
      await expect(asAdmin.getByText(`User ${newEmail} deleted`)).toBeVisible();
      await expect(asAdmin.getByTestId(`user-row-${newEmail}`)).toHaveCount(0);
    } finally {
      await cleanup(() => api.deleteUser(adminSession.token, user.id));
    }
  });

  test("a role gets a permission assigned and removed, is edited, then deleted", async ({
    asAdmin,
    adminSession,
    baseURL,
  }) => {
    const slug = unique("e2e-role").replace(/-/g, "_");
    const role = await api.createRole(adminSession.token, { name: `E2E ${slug}`, slug });
    try {
      await asAdmin.goto(appUrl(baseURL, "admin/roles"));
      const row = await showRow(asAdmin, `role-row-${slug}`);

      await row.getByRole("button", { name: "Permissions" }).click();
      const dialog = asAdmin.getByRole("dialog");
      const assigned = dialog.getByTestId("assigned-permissions");
      const available = dialog.getByTestId("available-permissions");
      await itemButton(available, "(system:logs)", "Assign").click();
      await expect(assigned).toContainText("system:logs");

      await itemButton(assigned, "(system:logs)", "Remove").click();
      await expect(assigned).toContainText("No permissions assigned");
      await dialog.getByRole("button", { name: "Close modal" }).click();
      await expect(dialog).toBeHidden();

      await row.getByRole("button", { name: "Edit" }).click();
      await asAdmin.getByRole("dialog").getByLabel("Description").fill("edited by e2e");
      await asAdmin.getByRole("dialog").getByRole("button", { name: "Update" }).click();
      await expect(row).toContainText("edited by e2e");

      asAdmin.once("dialog", (confirm) => void confirm.accept());
      await row.getByRole("button", { name: "Delete" }).click();
      await expect(asAdmin.getByTestId(`role-row-${slug}`)).toHaveCount(0);
    } finally {
      await cleanup(() => api.deleteRole(adminSession.token, role.id));
    }
  });

  test("a permission is created, edited and deleted", async ({ asAdmin, adminSession, baseURL }) => {
    const action = unique("x").replace(/-/g, "_");
    const slug = `e2e:${action}`;
    await asAdmin.goto(appUrl(baseURL, "admin/permissions"));

    await asAdmin.getByRole("button", { name: "Create Permission" }).click();
    let dialog = asAdmin.getByRole("dialog");
    await dialog.getByLabel("Name").fill(`E2E ${action}`);
    await dialog.getByLabel("Slug").fill(slug);
    await dialog.getByRole("button", { name: "Create" }).click();
    await expect(dialog).toBeHidden();

    try {
      const row = await showRow(asAdmin, `permission-row-${slug}`);
      await row.getByRole("button", { name: "Edit" }).click();
      dialog = asAdmin.getByRole("dialog");
      await dialog.getByLabel("Description").fill("edited by e2e");
      await dialog.getByRole("button", { name: "Update" }).click();
      await expect(row).toContainText("edited by e2e");

      asAdmin.once("dialog", (confirm) => void confirm.accept());
      await row.getByRole("button", { name: "Delete" }).click();
      await expect(asAdmin.getByTestId(`permission-row-${slug}`)).toHaveCount(0);
    } finally {
      await cleanup(async () => {
        const leftover = (await api.permissions(adminSession.token)).find((permission) => permission.slug === slug);
        if (leftover) await api.deletePermission(adminSession.token, leftover.id);
      });
    }
  });
});
