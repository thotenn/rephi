import { api, cleanup, TEST_PASSWORD, unique } from "./support/api";
import { appUrl, expect, test } from "./support/fixtures";

const quickActions = (page: import("@playwright/test").Page) =>
  page.getByRole("navigation", { name: "Quick actions" }).getByRole("link");

test.describe("dashboard quick actions", () => {
  test("an administrator sees all four, each a real link", async ({ asAdmin, baseURL }) => {
    await asAdmin.goto(appUrl(baseURL, "pages/dashboard"));

    await expect(quickActions(asAdmin)).toHaveText(["New role", "Send notification", "Manage users", "My profile"]);
    const hrefs = await quickActions(asAdmin).evaluateAll((links) => links.map((link) => link.getAttribute("href")));
    expect(hrefs).toEqual([
      new URL(appUrl(baseURL, "admin/roles?new=1")).pathname + "?new=1",
      new URL(appUrl(baseURL, "home")).pathname + "#notify",
      new URL(appUrl(baseURL, "admin/users")).pathname,
      new URL(appUrl(baseURL, "pages/profile")).pathname,
    ]);
  });

  test('"New role" opens the create-role form, which creates the role', async ({ asAdmin, adminSession, baseURL }) => {
    const slug = unique("e2e-role").replace(/-/g, "_");
    await asAdmin.goto(appUrl(baseURL, "pages/dashboard"));
    await asAdmin.getByRole("link", { name: "New role" }).click();

    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/roles?new=1"));
    const dialog = asAdmin.getByRole("dialog");
    await expect(dialog.getByRole("heading", { name: "Create Role" })).toBeVisible();

    await dialog.getByLabel("Name").fill(`E2E ${slug}`);
    await dialog.getByLabel("Slug").fill(slug);
    await dialog.getByRole("button", { name: "Create" }).click();

    await expect(dialog).toBeHidden();
    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/roles"));
    await expect(asAdmin.getByTestId(`role-row-${slug}`)).toBeVisible();

    const created = await api.roleBySlug(adminSession.token, slug);
    await cleanup(() => api.deleteRole(adminSession.token, created.id));
  });

  test('closing the form opened by "New role" drops ?new=1, so reloading does not reopen it', async ({
    asAdmin,
    baseURL,
  }) => {
    await asAdmin.goto(appUrl(baseURL, "admin/roles?new=1"));
    const dialog = asAdmin.getByRole("dialog");
    await expect(dialog.getByRole("heading", { name: "Create Role" })).toBeVisible();

    await dialog.getByRole("button", { name: "Cancel" }).click();
    await expect(dialog).toBeHidden();
    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/roles"));

    await asAdmin.reload();
    await expect(asAdmin.getByRole("button", { name: "Create Role" })).toBeVisible();
    await expect(asAdmin.getByRole("dialog")).toHaveCount(0);
  });

  test('"Send notification" lands on the broadcast form with the message field focused', async ({
    asAdmin,
    baseURL,
  }) => {
    await asAdmin.goto(appUrl(baseURL, "pages/dashboard"));
    await asAdmin.getByRole("link", { name: "Send notification" }).click();

    await expect(asAdmin).toHaveURL(appUrl(baseURL, "home#notify"));
    const message = asAdmin.getByRole("textbox", { name: "Notification message" });
    await expect(message).toBeFocused();

    await message.fill(`e2e broadcast ${Date.now()}`);
    await asAdmin.getByRole("button", { name: "Send", exact: true }).click();
    await expect(asAdmin.getByText("Notification sent!")).toBeVisible();
  });

  test('"Manage users" opens the user list', async ({ asAdmin, adminSession, baseURL }) => {
    await asAdmin.goto(appUrl(baseURL, "pages/dashboard"));
    await asAdmin.getByRole("link", { name: "Manage users" }).click();

    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/users"));
    await expect(asAdmin.getByTestId(`user-row-${adminSession.user.email}`)).toBeVisible();
  });

  test('"My profile" opens the profile with the change-password form', async ({ asAdmin, baseURL }) => {
    await asAdmin.goto(appUrl(baseURL, "pages/dashboard"));
    await asAdmin.getByRole("link", { name: "My profile" }).click();

    await expect(asAdmin).toHaveURL(appUrl(baseURL, "pages/profile"));
    await expect(asAdmin.getByRole("heading", { name: "Change Password" })).toBeVisible();
  });

  test("a plain user sees only the actions it may use", async ({ asPlainUser, baseURL }) => {
    await asPlainUser.goto(appUrl(baseURL, "pages/dashboard"));

    await expect(quickActions(asPlainUser)).toHaveText(["My profile"]);
    await asPlainUser.getByRole("link", { name: "My profile" }).click();
    await expect(asPlainUser).toHaveURL(appUrl(baseURL, "pages/profile"));
  });

  test("a manager sees the user list but not the actions it lacks permission for", async ({
    pageAs,
    adminSession,
    baseURL,
  }) => {
    const registered = await api.registerUnique("e2e-manager");
    try {
      const manager = await api.roleBySlug(adminSession.token, "manager");
      await api.assignRole(adminSession.token, registered.user.id, manager.id);
      const session = await api.login(registered.user.email, TEST_PASSWORD);

      const page = await pageAs(session);
      await page.goto(appUrl(baseURL, "pages/dashboard"));
      await expect(quickActions(page)).toHaveText(["Manage users", "My profile"]);
    } finally {
      await cleanup(() => api.deleteUser(adminSession.token, registered.user.id));
    }
  });
});
