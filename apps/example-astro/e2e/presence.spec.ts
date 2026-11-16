import { api, cleanup, TEST_PASSWORD } from "./support/api";
import { appUrl, expect, open, test } from "./support/fixtures";

// Its own Playwright project, run after the others: the count is global to the API.
test("Active sessions follows a second user signing in and leaving", async ({ pageAs, browser, adminSession, baseURL }) => {
  const first = await api.registerUnique("e2e-presence");
  const second = await api.registerUnique("e2e-presence");
  try {
    const before = (await api.dashboard(adminSession.token)).sessions.online_users;

    const page = await pageAs(first);
    await open(page, "pages/dashboard/");
    const sessions = page.getByTestId("tile-sessions-value");
    await expect(sessions).toHaveText(String(before + 1));

    const context = await browser.newContext();
    const other = await context.newPage();
    await other.goto(appUrl(baseURL, "login/"));
    await other.getByPlaceholder("Email address").fill(second.user.email);
    await other.getByPlaceholder("Password").fill(TEST_PASSWORD);
    await other.getByRole("button", { name: "Sign in" }).click();
    await expect(other).toHaveURL(appUrl(baseURL, "home/"));

    await expect(sessions).toHaveText(String(before + 2));

    await context.close();
    await expect(sessions).toHaveText(String(before + 1));
  } finally {
    await cleanup(() => api.deleteUser(adminSession.token, first.user.id));
    await cleanup(() => api.deleteUser(adminSession.token, second.user.id));
  }
});
