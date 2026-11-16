import { ADMIN, api, cleanup, TEST_PASSWORD, unique } from "./support/api";
import { appUrl, expect, open, test } from "./support/fixtures";

test.describe("session", () => {
  test("an administrator signs in through the form and lands on the home page", async ({ pageAs, baseURL }) => {
    const page = await pageAs(null);
    const urls: string[] = [];
    page.on("framenavigated", (frame) => urls.push(frame.url()));

    await page.goto(appUrl(baseURL, "login/"));
    await page.getByPlaceholder("Email address").fill(ADMIN.email);
    await page.getByPlaceholder("Password").fill(ADMIN.password);
    await page.getByRole("button", { name: "Sign in" }).click();

    await expect(page).toHaveURL(appUrl(baseURL, "home/"));
    await expect(page.getByText(ADMIN.email)).toBeVisible();
    await expect(page.getByRole("button", { name: "Admin" })).toBeVisible();
    expect(urls.filter((url) => url.includes("password")), "credentials in a URL").toEqual([]);
  });

  test("a protected page sends a visitor to the login page and back after signing in", async ({
    pageAs,
    adminSession,
    baseURL,
  }) => {
    const account = await api.registerUnique("e2e-redirect");
    const page = await pageAs(null);

    await page.goto(appUrl(baseURL, "pages/profile/"));
    await expect(page).toHaveURL(appUrl(baseURL, "login/"));
    await expect(page.getByText("You need to login to access that page.")).toBeVisible();

    await page.getByPlaceholder("Email address").fill(account.user.email);
    await page.getByPlaceholder("Password").fill(TEST_PASSWORD);
    await page.getByRole("button", { name: "Sign in" }).click();
    await expect(page).toHaveURL(appUrl(baseURL, "pages/profile/"));

    await cleanup(() => api.deleteUser(adminSession.token, account.user.id));
  });

  test("registering signs the new account in", async ({ pageAs, adminSession, baseURL }) => {
    const email = `${unique("e2e-register")}@example.com`;
    const page = await pageAs(null);

    await open(page, "register/");
    await page.getByLabel("Email address").fill(email);
    await page.getByLabel("Password", { exact: true }).fill(TEST_PASSWORD);
    await page.getByLabel("Confirm Password").fill(TEST_PASSWORD);
    await page.getByRole("button", { name: "Create account" }).click();

    await expect(page).toHaveURL(appUrl(baseURL, "home/"));
    await expect(page.getByText(email)).toBeVisible();

    const session = await api.login(email, TEST_PASSWORD);
    await cleanup(() => api.deleteUser(adminSession.token, session.user.id));
  });

  test("logout ends the session and returns to the login page", async ({ pageAs, adminSession, baseURL }) => {
    const account = await api.registerUnique("e2e-logout");
    const page = await pageAs(account);

    await open(page, "home/");
    await page.getByRole("button", { name: "Logout" }).click();
    await expect(page).toHaveURL(appUrl(baseURL, "login/"));
    await expect(page.getByText("You have been signed out.")).toBeVisible();

    await open(page, "home/");
    await expect(page).toHaveURL(appUrl(baseURL, "login/"));

    await cleanup(() => api.deleteUser(adminSession.token, account.user.id));
  });
});

test.describe("administration", () => {
  test("a role is edited and deleted from the roles screen", async ({ asAdmin, adminSession }) => {
    const slug = unique("e2e-crud").replace(/-/g, "_");
    const role = await api.createRole(adminSession.token, { name: `E2E ${slug}`, slug });

    try {
      await open(asAdmin, "admin/roles/");
      const row = asAdmin.getByTestId(`role-row-${slug}`);
      await expect(row).toBeVisible();

      await row.getByRole("button", { name: "Edit" }).click();
      const dialog = asAdmin.getByRole("dialog");
      await dialog.getByLabel("Name").fill(`E2E renamed ${slug}`);
      await dialog.getByRole("button", { name: "Update" }).click();
      await expect(dialog).toBeHidden();
      await expect(row).toContainText(`E2E renamed ${slug}`);

      asAdmin.once("dialog", (confirm) => void confirm.accept());
      await row.getByRole("button", { name: "Delete" }).click();
      await expect(row).toHaveCount(0);
    } finally {
      await cleanup(() => api.deleteRole(adminSession.token, role.id));
    }
  });

  test("a user's role is assigned and removed from the users screen", async ({ asAdmin, adminSession }) => {
    const account = await api.registerUnique("e2e-roles");

    try {
      await open(asAdmin, "admin/users/");
      const row = asAdmin.getByTestId(`user-row-${account.user.email}`);
      await expect(row).toBeVisible();

      await row.getByRole("button", { name: "Manage Roles" }).click();
      const dialog = asAdmin.getByRole("dialog");
      const available = dialog.getByTestId("available-roles");
      const current = dialog.getByTestId("current-roles");
      await available.locator("div", { hasText: "Manager" }).getByRole("button", { name: "Assign" }).first().click();
      await expect(current).toContainText("Manager");
      await current.locator("div", { hasText: "Manager" }).getByRole("button", { name: "Remove" }).first().click();
      await expect(current).not.toContainText("Manager");
    } finally {
      await cleanup(() => api.deleteUser(adminSession.token, account.user.id));
    }
  });
});
