import type { TransitionBeforePreparationEvent } from "astro:transitions/client";

// In dev, Astro's loader also loads every page with client:only islands in a
// hidden iframe, only to copy CSS imported by islands. These islands import none.
export function skipDevIframePreload(): void {
  document.addEventListener("astro:before-preparation", (event) => {
    const preparation = event as TransitionBeforePreparationEvent;
    if (preparation.formData) return;

    preparation.loader = async () => {
      const response = await fetch(preparation.to.href, { signal: preparation.signal }).catch(
        () => null
      );
      const mediaType = response?.headers.get("content-type")?.split(";", 1)[0].trim();
      if (!response || mediaType !== "text/html") {
        preparation.preventDefault();
        return;
      }
      if (response.redirected) {
        const to = new URL(response.url);
        if (to.origin !== preparation.to.origin) {
          preparation.preventDefault();
          return;
        }
        to.hash = preparation.to.hash;
        preparation.to = to;
      }
      const html = await response.text().catch(() => null);
      if (html === null) {
        preparation.preventDefault();
        return;
      }
      preparation.newDocument = new DOMParser().parseFromString(html, "text/html");
      if (!preparation.newDocument.querySelector('[name="astro-view-transitions-enabled"]')) {
        preparation.preventDefault();
      }
    };
  });
}
