/**
 * Single entry point to `@rephi/shared-components` for this app.
 *
 * The shared library ships with the API / socket URLs that were inlined when
 * *it* was built. This module overrides them with the app's own public
 * environment variables before anything can issue a request or open a socket.
 * Import the library from here (`~/lib/rephi`), never directly: every island is
 * a separate entry point, and this guarantees each of them runs the
 * configuration first. ESLint enforces it (see eslint.config.js).
 */
// eslint-disable-next-line @typescript-eslint/no-restricted-imports
import { configureRephi } from "@rephi/shared-components";
import { PUBLIC_API_URL, PUBLIC_WS_URL } from "astro:env/client";

configureRephi({ apiUrl: PUBLIC_API_URL, wsUrl: PUBLIC_WS_URL });

// eslint-disable-next-line @typescript-eslint/no-restricted-imports
export * from "@rephi/shared-components";
