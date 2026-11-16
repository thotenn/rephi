import { test as base, expect, type Browser, type Page } from "@playwright/test";
import type { Session } from "./api";

const AUTH_STORAGE_KEY = "auth-storage";

function sharedSession(variable: "E2E_ADMIN_SESSION" | "E2E_PLAIN_SESSION"): Session {
  const value = process.env[variable];
  if (!value) throw new Error(`${variable} is not set: run the tests with \`yarn e2e\` (global setup).`);
  return JSON.parse(value) as Session;
}

export function appUrl(baseURL: string | undefined, path: string): string {
  return new URL(path.replace(/^\//, ""), baseURL).toString();
}

// Islands nested in the route guard enter the DOM only after the guard renders.
export async function islandsReady(page: Page): Promise<void> {
  await page.waitForFunction(
    () =>
      new Promise<boolean>((resolve) => {
        const idle = () => !document.querySelector("astro-island[ssr]");
        if (!idle()) return resolve(false);
        requestAnimationFrame(() => requestAnimationFrame(() => resolve(idle())));
      })
  );
}

export async function open(page: Page, path: string): Promise<void> {
  await page.goto(appUrl(test.info().project.use.baseURL, path));
  await islandsReady(page);
}

async function signedInPage(browser: Browser, baseURL: string | undefined, session: Session | null) {
  const origin = new URL(baseURL ?? "").origin;
  const context = await browser.newContext({
    storageState: {
      cookies: [],
      origins: session
        ? [
            {
              origin,
              localStorage: [
                {
                  name: AUTH_STORAGE_KEY,
                  value: JSON.stringify({
                    state: { user: session.user, token: session.token, isAuthenticated: true },
                    version: 0,
                  }),
                },
              ],
            },
          ]
        : [],
    },
  });
  const page = await context.newPage();
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  return { page, errors, close: () => context.close() };
}

interface Fixtures {
  adminSession: Session;
  plainSession: Session;
  asAdmin: Page;
  asPlainUser: Page;
  pageAs: (session: Session | null) => Promise<Page>;
}

export const test = base.extend<Fixtures>({
  // eslint-disable-next-line no-empty-pattern -- Playwright requires the destructuring.
  adminSession: async ({}, provide) => {
    await provide(sharedSession("E2E_ADMIN_SESSION"));
  },
  // eslint-disable-next-line no-empty-pattern -- Playwright requires the destructuring.
  plainSession: async ({}, provide) => {
    await provide(sharedSession("E2E_PLAIN_SESSION"));
  },
  pageAs: async ({ browser, baseURL }, provide) => {
    const opened: Awaited<ReturnType<typeof signedInPage>>[] = [];
    await provide(async (session) => {
      const entry = await signedInPage(browser, baseURL, session);
      opened.push(entry);
      return entry.page;
    });
    for (const entry of opened) {
      await entry.close();
      expect(entry.errors, "uncaught errors in the page").toEqual([]);
    }
  },
  asAdmin: async ({ pageAs, adminSession }, provide) => {
    await provide(await pageAs(adminSession));
  },
  asPlainUser: async ({ pageAs, plainSession }, provide) => {
    await provide(await pageAs(plainSession));
  },
});

export { expect };
