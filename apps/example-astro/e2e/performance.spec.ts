import type { CDPSession, Page } from "@playwright/test";
import { appUrl, expect, islandsReady, open, test } from "./support/fixtures";

interface Request {
  url: string;
  type: string;
  frameId: string;
  fromCache: boolean;
  bytes: number;
}

async function recordRequests(page: Page) {
  const cdp: CDPSession = await page.context().newCDPSession(page);
  await cdp.send("Network.enable");
  const { frameTree } = await cdp.send("Page.getFrameTree");
  const requests = new Map<string, Request>();

  cdp.on("Network.requestWillBeSent", (event) => {
    requests.set(event.requestId, {
      url: event.request.url,
      type: event.type ?? "Other",
      frameId: event.frameId ?? "",
      fromCache: false,
      bytes: 0,
    });
  });
  cdp.on("Network.requestServedFromCache", (event) => {
    const request = requests.get(event.requestId);
    if (request) request.fromCache = true;
  });
  cdp.on("Network.responseReceived", (event) => {
    const request = requests.get(event.requestId);
    if (request && (event.response.fromDiskCache || event.response.fromPrefetchCache)) request.fromCache = true;
  });
  cdp.on("Network.loadingFinished", (event) => {
    const request = requests.get(event.requestId);
    if (request) request.bytes = event.encodedDataLength;
  });

  return {
    mainFrame: frameTree.frame.id,
    take: () => {
      const taken = [...requests.values()];
      requests.clear();
      return taken;
    },
  };
}

async function isDevServer(page: Page, baseURL: string | undefined): Promise<boolean> {
  const response = await page.request.get(appUrl(baseURL, "login/"));
  return (await response.text()).includes("/@vite/client");
}

const tour = [
  { link: "Profile", path: "pages/profile/", ready: "Change Password" },
  { link: "Dashboard", path: "pages/dashboard/", ready: "Quick Actions" },
  { admin: "User Management", path: "admin/users/", ready: "Joined" },
  { admin: "Roles Management", path: "admin/roles/", ready: "Create Role" },
  { link: "Home", path: "home/", ready: "User Information" },
];

async function navigate(page: Page, baseURL: string | undefined, step: (typeof tour)[number]) {
  await page.evaluate(() => ((window as { __e2eDocument?: boolean }).__e2eDocument = true));
  if (step.admin) {
    await page.getByRole("button", { name: "Admin" }).click();
    await page.getByRole("link", { name: step.admin }).click();
  } else {
    await page.getByRole("navigation", { name: "Main" }).getByRole("link", { name: step.link, exact: true }).click();
  }
  await expect(page).toHaveURL(appUrl(baseURL, step.path));
  await expect(page.getByText(step.ready, { exact: true }).first()).toBeVisible();
  await islandsReady(page);
  await page.waitForLoadState("networkidle");
  const sameDocument = await page.evaluate(() => (window as { __e2eDocument?: boolean }).__e2eDocument === true);
  expect(sameDocument, `${step.path} was swapped in by the client router, not loaded as a new document`).toBe(true);
}

test.describe("navigation performance", () => {
  test("client-side navigations re-download no JavaScript", async ({ asAdmin, baseURL }) => {
    test.skip(await isDevServer(asAdmin, baseURL), "Production build only: the dev server serves unbundled modules.");
    const network = await recordRequests(asAdmin);

    await open(asAdmin, "home/");
    const asset = network.take().find((request) => new URL(request.url).pathname.includes("/_astro/"));
    expect(asset, "the page loads hashed assets from /_astro/").toBeDefined();
    const headers = (await asAdmin.request.get(asset!.url)).headers();
    expect(headers["cache-control"]).toContain("immutable");

    for (const step of tour) await navigate(asAdmin, baseURL, step);
    network.take();

    for (const step of tour) {
      await navigate(asAdmin, baseURL, step);
      const requests = network.take().filter((request) => new URL(request.url).origin === new URL(baseURL!).origin);
      const documents = requests.filter((request) => request.type === "Document");
      const downloaded = requests.filter(
        (request) => new URL(request.url).pathname.includes("/_astro/") && !request.fromCache && request.bytes > 0
      );
      expect(documents, `${step.path}: full document loads`).toEqual([]);
      expect(
        downloaded.map((request) => request.url),
        `${step.path}: assets downloaded again`
      ).toEqual([]);
    }
  });

  test("dev server: a navigation does not load the next page a second time in a hidden frame", async ({
    asAdmin,
    baseURL,
  }) => {
    test.skip(!(await isDevServer(asAdmin, baseURL)), "Dev server only.");
    const network = await recordRequests(asAdmin);

    await open(asAdmin, "home/");
    network.take();
    for (const step of tour) {
      await navigate(asAdmin, baseURL, step);
      const requests = network.take().filter((request) => new URL(request.url).origin === new URL(baseURL!).origin);
      const framed = requests.filter((request) => request.frameId !== network.mainFrame);
      expect(
        framed.map((request) => request.url),
        `${step.path}: requests of a hidden frame`
      ).toEqual([]);
      expect(requests.filter((request) => request.type === "Document")).toEqual([]);
    }
  });
});
