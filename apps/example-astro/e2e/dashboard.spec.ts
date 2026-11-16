import type { Page } from "@playwright/test";
import { api, cleanup, unique } from "./support/api";
import { appUrl, expect, open, test } from "./support/fixtures";

const quickActions = (page: Page) => page.getByRole("navigation", { name: "Quick actions" }).getByRole("link");

const pathOf = (baseURL: string | undefined, path: string) => {
  const url = new URL(appUrl(baseURL, path));
  return `${url.pathname}${url.search}${url.hash}`;
};

test.describe("dashboard quick actions", () => {
  test("an administrator sees all four, each a real link", async ({ asAdmin, baseURL }) => {
    await open(asAdmin, "pages/dashboard/");

    await expect(quickActions(asAdmin)).toHaveText(["New role", "Send notification", "Manage users", "My profile"]);
    const hrefs = await quickActions(asAdmin).evaluateAll((links) => links.map((link) => link.getAttribute("href")));
    expect(hrefs).toEqual([
      pathOf(baseURL, "admin/roles/?new=1"),
      pathOf(baseURL, "home/#notify"),
      pathOf(baseURL, "admin/users/"),
      pathOf(baseURL, "pages/profile/"),
    ]);
  });

  test("a plain user only gets the profile shortcut", async ({ asPlainUser }) => {
    await open(asPlainUser, "pages/dashboard/");
    await expect(quickActions(asPlainUser)).toHaveText(["My profile"]);
  });

  test('"New role" opens the create-role form, which creates the role', async ({ asAdmin, adminSession, baseURL }) => {
    const slug = unique("e2e-role").replace(/-/g, "_");
    await open(asAdmin, "pages/dashboard/");
    await asAdmin.getByRole("link", { name: "New role" }).click();

    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/roles/?new=1"));
    const dialog = asAdmin.getByRole("dialog");
    await expect(dialog.getByRole("heading", { name: "Create Role" })).toBeVisible();

    await dialog.getByLabel("Name").fill(`E2E ${slug}`);
    await dialog.getByLabel("Slug").fill(slug);
    await dialog.getByRole("button", { name: "Create" }).click();

    await expect(dialog).toBeHidden();
    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/roles/"));
    await expect(asAdmin.getByTestId(`role-row-${slug}`)).toBeVisible();

    const created = await api.roleBySlug(adminSession.token, slug);
    await cleanup(() => api.deleteRole(adminSession.token, created.id));
  });

  test("closing the form drops ?new=1, so reloading does not reopen it", async ({ asAdmin, baseURL }) => {
    await open(asAdmin, "admin/roles/?new=1");
    const dialog = asAdmin.getByRole("dialog");
    await expect(dialog.getByRole("heading", { name: "Create Role" })).toBeVisible();

    await dialog.getByRole("button", { name: "Cancel" }).click();
    await expect(dialog).toBeHidden();
    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/roles/"));

    await asAdmin.reload();
    await expect(asAdmin.getByRole("button", { name: "Create Role" })).toBeVisible();
    await expect(asAdmin.getByRole("dialog")).toHaveCount(0);
  });

  test('"Send notification" lands on the broadcast form with the message field focused', async ({
    asAdmin,
    baseURL,
  }) => {
    await open(asAdmin, "pages/dashboard/");
    await asAdmin.getByRole("link", { name: "Send notification" }).click();

    await expect(asAdmin).toHaveURL(appUrl(baseURL, "home/#notify"));
    const message = asAdmin.getByRole("textbox", { name: "Notification message" });
    await expect(message).toBeFocused();

    const text = `e2e broadcast ${unique("msg")}`;
    await message.fill(text);
    await asAdmin.getByRole("button", { name: "Send", exact: true }).click();
    await expect(asAdmin.getByText("Notification sent!")).toBeVisible();
    await expect(asAdmin.getByText(text)).toHaveCount(1);
    await asAdmin.waitForTimeout(1_000);
    await expect(asAdmin.getByText(text), "the broadcast is shown once").toHaveCount(1);
  });

  test('"Manage users" opens the user list', async ({ asAdmin, adminSession, baseURL }) => {
    await open(asAdmin, "pages/dashboard/");
    await asAdmin.getByRole("link", { name: "Manage users" }).click();

    await expect(asAdmin).toHaveURL(appUrl(baseURL, "admin/users/"));
    await expect(asAdmin.getByTestId(`user-row-${adminSession.user.email}`)).toBeVisible();
  });

  test('"My profile" opens the profile page', async ({ asPlainUser, plainSession, baseURL }) => {
    await open(asPlainUser, "pages/dashboard/");
    await asPlainUser.getByRole("link", { name: "My profile" }).click();

    await expect(asPlainUser).toHaveURL(appUrl(baseURL, "pages/profile/"));
    await expect(asPlainUser.getByRole("heading", { name: "Change Password" })).toBeVisible();
    await expect(asPlainUser.getByText(plainSession.user.email)).toBeVisible();
  });
});
