import type { Locator, Page } from "@playwright/test";

export interface Control {
  role: string;
  name: string;
  tag: string;
  label: string;
}

export interface ProbeOptions {
  open: () => Promise<void>;
  scope?: string;
  skip?: RegExp;
  depth?: number;
}

export interface ProbeResult {
  exercised: string[];
  dead: string[];
  skipped: string[];
}

const CONTROL_SELECTOR = 'a[href], button, [role="button"], [role="menuitem"], [role="link"], [role="tab"]';

// They change on their own: their mutations say nothing about a click.
const NOISY_SELECTOR = '[data-rht-toaster], [data-testid="realtime-status"], [data-testid="realtime-hint"]';

declare global {
  interface Window {
    __e2eMutations?: number;
    __e2eObserver?: MutationObserver;
  }
}

async function listControls(page: Page, scope: string): Promise<Omit<Control, "label">[]> {
  return page.locator(scope).first().evaluate(
    (root, selector) => {
      const seen = new Set<string>();
      const result: { role: string; name: string; tag: string }[] = [];
      for (const element of Array.from(root.querySelectorAll<HTMLElement>(selector))) {
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        if (rect.width === 0 || rect.height === 0 || style.visibility === "hidden") continue;
        const tag = element.tagName.toLowerCase();
        const role = element.getAttribute("role") ?? (tag === "a" ? "link" : "button");
        const name = (element.getAttribute("aria-label") ?? element.textContent ?? "").replace(/\s+/g, " ").trim();
        const key = `${role}|${name}|${tag}`;
        if (seen.has(key)) continue;
        seen.add(key);
        result.push({ role, name, tag });
      }
      return result;
    },
    CONTROL_SELECTOR
  );
}

function locate(page: Page, scope: string, control: Omit<Control, "label">): Locator {
  return page
    .locator(scope)
    .first()
    .locator(control.tag)
    .and(page.getByRole(control.role as Parameters<Page["getByRole"]>[0], { name: control.name, exact: true }))
    .and(page.locator(":not([disabled])"))
    .first();
}

async function clickAndObserve(page: Page, target: Locator, control: Omit<Control, "label">): Promise<string | null> {
  await page.waitForLoadState("networkidle");
  await page.evaluate((noisy) => {
    window.__e2eObserver?.disconnect();
    window.__e2eMutations = 0;
    const observer = new MutationObserver((records) => {
      for (const record of records) {
        const node = record.target instanceof Element ? record.target : record.target.parentElement;
        if (!node?.closest(noisy)) window.__e2eMutations = (window.__e2eMutations ?? 0) + 1;
      }
    });
    observer.observe(document.body, { subtree: true, childList: true, attributes: true, characterData: true });
    window.__e2eObserver = observer;
  }, NOISY_SELECTOR);

  const withoutEmptyHash = (url: string) => url.replace(/#$/, "");
  const urlBefore = withoutEmptyHash(page.url());
  let requests = 0;
  let browserDialog: string | null = null;
  const onRequest = () => {
    requests += 1;
  };
  const onDialog = (dialog: { type(): string; message(): string; dismiss(): Promise<void> }) => {
    browserDialog = `${dialog.type()} "${dialog.message()}"`;
    void dialog.dismiss();
  };
  page.on("request", onRequest);
  page.on("dialog", onDialog);

  try {
    // The middle of a modal backdrop is the dialog itself.
    const isBackdrop = control.tag !== "button" && control.tag !== "a" && (await target.locator('[role="dialog"]').count()) > 0;
    await target.click(isBackdrop ? { position: { x: 4, y: 4 } } : undefined);

    const deadline = Date.now() + 2_000;
    while (Date.now() < deadline) {
      if (withoutEmptyHash(page.url()) !== urlBefore) {
        const url = new URL(page.url());
        return `navigated to ${url.pathname}${url.search}${url.hash}`;
      }
      if (browserDialog) return `opened ${browserDialog}`;
      if (requests > 0) return "sent a request";
      const mutations = await page.evaluate(() => window.__e2eMutations ?? 0).catch(() => 1);
      if (mutations > 0) return "changed the page";
      await page.waitForTimeout(100);
    }
    return null;
  } finally {
    page.off("request", onRequest);
    page.off("dialog", onDialog);
  }
}

export async function probeControls(page: Page, options: ProbeOptions): Promise<ProbeResult> {
  const result: ProbeResult = { exercised: [], dead: [], skipped: [] };
  await explore(page, options.open, options.scope ?? "body", options.skip, options.depth ?? 2, [], "", result);
  return result;
}

async function explore(
  page: Page,
  open: () => Promise<void>,
  scope: string,
  skip: RegExp | undefined,
  depth: number,
  known: string[],
  path: string,
  result: ProbeResult
): Promise<void> {
  await open();
  await page.waitForLoadState("networkidle");
  const controls = (await listControls(page, scope)).filter((c) => !known.includes(key(c)));
  const keys = [...known, ...controls.map(key)];

  for (const control of controls) {
    const label = `${path}${control.role} "${control.name}"${control.tag === "a" || control.tag === "button" ? "" : ` <${control.tag}>`}`;
    if (skip?.test(control.name)) {
      result.skipped.push(`${label} (changes data or ends the session: covered by its own test)`);
      continue;
    }

    await open();
    await page.waitForLoadState("networkidle");
    const target = locate(page, scope, control);
    if ((await target.count()) === 0) {
      result.skipped.push(`${label} (disabled)`);
      continue;
    }
    if ((await target.getAttribute("aria-current")) === "page") {
      result.skipped.push(`${label} (link to the current page)`);
      continue;
    }

    const effect = await clickAndObserve(page, target, control);
    if (!effect) {
      result.dead.push(label);
      continue;
    }
    result.exercised.push(`${label}: ${effect}`);

    if (depth > 1 && !effect.startsWith("navigated") && !effect.startsWith("opened")) {
      const reopen = async () => {
        await open();
        await page.waitForLoadState("networkidle");
        await locate(page, scope, control).click();
      };
      await explore(page, reopen, scope, skip, depth - 1, keys, `${label} > `, result);
    }
  }
}

function key(control: Omit<Control, "label">): string {
  return `${control.role}|${control.name}|${control.tag}`;
}
