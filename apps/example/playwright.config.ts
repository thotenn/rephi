import { defineConfig, type PlaywrightTestConfig } from "@playwright/test";

// Settings: e2e/README.md.
const baseURL = withTrailingSlash(process.env.E2E_BASE_URL ?? "http://localhost:5101/app/example/");
const apiURL = process.env.E2E_API_URL ?? "http://localhost:4100/api";
const channel = process.env.E2E_BROWSER_CHANNEL ?? "chrome";

function withTrailingSlash(url: string): string {
  return url.endsWith("/") ? url : `${url}/`;
}

function stack(): PlaywrightTestConfig["webServer"] {
  const app = new URL(baseURL);
  const api = new URL(apiURL);
  const database = process.env.E2E_DB_NAME ?? "rephi_e2e";
  const socketURL = `${api.protocol === "https:" ? "wss" : "ws"}://${api.host}/socket`;

  return [
    {
      command: "mix ecto.setup && mix phx.server",
      cwd: "../..",
      url: `${api.origin}/api/health`,
      reuseExistingServer: true,
      timeout: 180_000,
      env: {
        PORT: api.port,
        DB_NAME: database,
        CORS_ORIGINS: app.origin,
        RATE_LIMIT_ENABLED: "false",
      },
    },
    {
      command: "yarn dev",
      url: baseURL,
      reuseExistingServer: true,
      timeout: 60_000,
      env: {
        VITE_PORT: app.port,
        VITE_API_URL: apiURL,
        VITE_WS_URL: socketURL,
      },
    },
  ];
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
  reporter: "list",
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
  webServer: process.env.E2E_START_STACK ? stack() : undefined,
});
