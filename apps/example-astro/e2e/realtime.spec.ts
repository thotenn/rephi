import type { Page } from "@playwright/test";
import { api, cleanup, TEST_PASSWORD, unique, type Session } from "./support/api";
import { expect, open, test } from "./support/fixtures";

const tile = (page: Page, id: string) => page.getByTestId(`tile-${id}`);
const tileValue = (page: Page, id: string) => page.getByTestId(`tile-${id}-value`);

async function openHome(page: Page) {
  await open(page, "home/");
  await expect(page.getByTestId("realtime-status")).toHaveText(/Connected/);
}

async function withUsers(adminToken: string, count: number, run: (sessions: Session[]) => Promise<void>) {
  const sessions: Session[] = [];
  try {
    for (let i = 0; i < count; i += 1) sessions.push(await api.registerUnique("e2e-realtime"));
    await run(sessions);
  } finally {
    for (const session of sessions) await cleanup(() => api.deleteUser(adminToken, session.user.id));
  }
}

test.describe("dashboard tiles", () => {
  test("an administrator sees users, every broadcast and the sessions", async ({ pageAs, adminSession }) => {
    await withUsers(adminSession.token, 1, async ([registered]) => {
      const admin = await api.roleBySlug(adminSession.token, "admin");
      await api.assignRole(adminSession.token, registered.user.id, admin.id);
      const session = await api.login(registered.user.email, TEST_PASSWORD);
      await api.sendTestNotification(session.token, unique("e2e-count"));
      const before = await api.dashboard(adminSession.token);

      const page = await pageAs(session);
      await open(page, "pages/dashboard/");

      await expect(tile(page, "users")).toContainText("Total Users");
      await expect(tileValue(page, "users")).toHaveText(/^\d+$/);
      expect(Number(await tileValue(page, "users").textContent())).toBeGreaterThanOrEqual(2);

      await expect(tile(page, "notifications")).toContainText("Notifications Sent");
      await expect(tileValue(page, "notifications")).toHaveText(/^\d+$/);
      expect(Number(await tileValue(page, "notifications").textContent())).toBeGreaterThanOrEqual(
        before.notifications.sent_total ?? 0
      );
      await expect(page.getByTestId("tile-notifications-detail")).toHaveText("1 by you");

      await expect(tile(page, "sessions")).toContainText("Active Sessions");
      await expect(tileValue(page, "sessions")).toHaveText(/^[1-9]\d*$/);
      await expect(page.getByTestId("tile-sessions-detail")).toHaveText(/^\d+ connections?$/);
    });
  });

  test("a plain user sees only what it sent and the sessions, refreshed after sending", async ({
    pageAs,
    adminSession,
  }) => {
    await withUsers(adminSession.token, 1, async ([session]) => {
      await api.sendTestNotification(session.token, unique("e2e-count"));
      await api.sendTestNotification(session.token, unique("e2e-count"));

      const page = await pageAs(session);
      await open(page, "pages/dashboard/");

      await expect(tile(page, "notifications")).toContainText("Notifications You Sent");
      await expect(tileValue(page, "notifications")).toHaveText("2");
      await expect(tileValue(page, "sessions")).toHaveText(/^[1-9]\d*$/);
      await expect(tile(page, "users")).toHaveCount(0);
      await expect(page.getByTestId("tile-notifications-detail")).toHaveCount(0);

      await page.getByRole("link", { name: "Home", exact: true }).click();
      await expect(page.getByTestId("realtime-status")).toHaveText(/Connected/);
      await page.getByRole("button", { name: "Send a test to myself" }).click();
      await expect(page.getByText("Test notification sent to you")).toBeVisible();

      await page.getByRole("link", { name: "Dashboard", exact: true }).click();
      await expect(tileValue(page, "notifications")).toHaveText("3");
    });
  });
});

test.describe("notifications", () => {
  test("a test to myself is shown once to the sender and to nobody else", async ({ pageAs, adminSession }) => {
    await withUsers(adminSession.token, 2, async ([sender, other]) => {
      const senderPage = await pageAs(sender);
      const otherPage = await pageAs(other);
      await openHome(senderPage);
      await openHome(otherPage);

      await expect(
        senderPage.getByText("Sending to everyone requires the notifications:broadcast permission.", { exact: false })
      ).toBeVisible();
      await expect(senderPage.getByRole("button", { name: "Send", exact: true })).toHaveCount(0);

      const message = unique("e2e-self");
      await senderPage.getByRole("textbox", { name: "Notification message" }).fill(message);
      await senderPage.getByRole("button", { name: "Send a test to myself" }).click();

      const toast = senderPage.getByRole("status").filter({ hasText: message });
      await expect(toast).toHaveCount(1);
      await expect(toast).toContainText(`From ${sender.user.email}`);
      await senderPage.waitForTimeout(1_500);
      await expect(senderPage.getByText(message)).toHaveCount(1);
      await expect(otherPage.getByText(message)).toHaveCount(0);

      const broadcast = unique("e2e-broadcast");
      await api.broadcast(adminSession.token, broadcast);
      await expect(senderPage.getByText(broadcast)).toHaveCount(1);
      await expect(otherPage.getByText(broadcast)).toHaveCount(1);
    });
  });

  test("an administrator gets the broadcast form and the test to itself", async ({ asAdmin, adminSession }) => {
    await openHome(asAdmin);
    await expect(asAdmin.getByRole("button", { name: "Send", exact: true })).toBeVisible();

    const message = unique("e2e-admin-self");
    await asAdmin.getByRole("textbox", { name: "Notification message" }).fill(message);
    await asAdmin.getByRole("button", { name: "Send a test to myself" }).click();
    await expect(asAdmin.getByRole("status").filter({ hasText: message })).toContainText(
      `From ${adminSession.user.email}`
    );
  });
});
