import { defineConfig } from "@playwright/test";

const baseURL = withTrailingSlash(process.env.E2E_BASE_URL ?? "http://localhost:4401/");
const apiURL = process.env.E2E_API_URL ?? "http://localhost:4110/api";
const channel = process.env.E2E_BROWSER_CHANNEL ?? "chrome";

function withTrailingSlash(url: string): string {
  return url.endsWith("/") ? url : `${url}/`;
}

export default defineConfig({
  testDir: "./e2e",
  outputDir: "./e2e/.results",
  globalSetup: "./e2e/global-setup.ts",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : 4,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: process.env.CI ? [["list"], ["html", { open: "never", outputFolder: "e2e/.report" }]] : "list",
  use: {
    baseURL,
    channel: channel === "chromium" ? undefined : channel,
    headless: !process.env.E2E_HEADED,
    viewport: { width: 1280, height: 900 },
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "app", testIgnore: /presence\.spec\.ts/ },
    { name: "presence", testMatch: /presence\.spec\.ts/, dependencies: ["app"] },
  ],
  metadata: { apiURL },
});
